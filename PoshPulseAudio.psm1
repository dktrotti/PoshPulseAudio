. $PSScriptRoot/PAParsing.ps1
. $PSScriptRoot/PADataStructs.ps1

function New-PulseAudioProfile {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $profileData
    )
    $pattern = "^(?<name>.*): (?<displayName>.*) \(sinks: (?<sinkCount>[0-9]+), sources: (?<sourceCount>[0-9]+), priority: (?<priority>[0-9]+), available: (?<available>yes|no)"
    if ($profileData -match $pattern) {
        return [PulseAudioProfile] @{
            SymbolicName = $Matches.name
            DisplayName = $Matches.displayName
            SinkCount = $Matches.sinkCount
            SourceCount = $Matches.sourceCount
            Priority = $Matches.priority
            Available = $Matches.available -eq "yes"
        }
    } else {
        Write-Warning "Unexpected profile data format: $profileData"
    }
}

<#
    .SYNOPSIS
    Gets all Pulse Audio cards. (See `pactl list cards` for details)

    .PARAMETER Name
    The name of the desired cards, or a pattern to match the name against.

    .OUTPUTS
    A list of PulseAudioCards matching the provided pattern, or all cards if no name was specified.
#>
function Get-PACard {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Name
    )
    pactl list cards |
        Split-IndentedData |
        ForEach-Object {
            $profiles = $_.FindChild("^Profiles:.*").Children | ForEach-Object { New-PulseAudioProfile $_.Value }
            $activeProfileName = $_.ParseChildValue("Active Profile: ")
            [PulseAudioCard] @{
                Index = $_.ParseValue("Card #")
                Name = $_.ParseChildValue("Name: ")
                Driver = $_.ParseChildValue("Driver: ")
                Profiles = $profiles
                ActiveProfile = $profiles | Where-Object { $_.SymbolicName -eq $activeProfileName } | Select-Object -First 1
            }
        } |
        # Do not filter on $Name if it is not set
        Where-Object { -not $Name -or $_.Name -like $Name }
}

<#
    .SYNOPSIS
    Sets the active profile of the specified Pulse Audio card. (See `pactl set-card-profile` for details)

    .PARAMETER PACard
    The PulseAudioCard to be updated, or the name of the card.

    .PARAMETER PAProfile
    The PulseAudioProfile to be used, or the name of the profile.

    .INPUTS
    See parameter PACard.

    .OUTPUTS
    None
#>
function Set-PACardProfile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]
        $PACard,
        [Parameter(Mandatory)]
        [object]
        $PAProfile
    )
    # Because the test dot-sources PADataStructs.ps1 separately, the -is operator cannot be used
    # here because the type handle is not the same
    if ($PACard.GetType().Name -eq 'PulseAudioCard') {
        $PACardName = $PACard.Name
    } else {
        $PACardName = [string] $PACard
    }

    if ($PAProfile.GetType().Name -eq 'PulseAudioProfile') {
        $PAProfileName = $PAProfile.SymbolicName
    } else {
        $PAProfileName = [string] $PAProfile
    }

    $output = pactl set-card-profile $PACardName $PAProfileName
    if ($output) {            
        throw "Could not set profile for $PACardName to $PAProfileName`: $output"
    }
}

<#
    .SYNOPSIS
    Gets all Pulse Audio output devices. (See `pactl list sinks` for details)

    .PARAMETER Name
    The name of the desired sink, or a pattern to match the name against.

    .OUTPUTS
    A list of PulseAudioSinks matching the provided pattern, or all sinks if no name was specified.
#>
function Get-PASink {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Name
    )
    pactl list sinks |
        Split-IndentedData |
        ForEach-Object {
            [PulseAudioSink] @{
                Index = $_.ParseValue("Sink #")
                Name = $_.ParseChildValue("Name: ")
                Description = $_.ParseChildValue("Description: ")
            }
        } |
        # Do not filter on $Name if it is not set
        Where-Object { -not $Name -or $_.Name -like $Name }
}

<#
    .SYNOPSIS
    Gets all applications outputting audio to Pulse Audio output devices. (See `pactl list sink-inputs` for details)

    .OUTPUTS
    A list of PulseAudioSinkInputs.
#>
function Get-PASinkInput {
    pactl list sink-inputs |
        Split-IndentedData |
        ForEach-Object {
            [PulseAudioSinkInput] @{
                Index = $_.ParseValue("Sink Input #")
                ApplicationName = $_.FindChild("Properties").ParseChildValue("application.name = ").Trim('"')
                BinaryName = $_.FindChild("Properties").ParseChildValue("application.process.binary = ").Trim('"')
                ProcessId = $_.FindChild("Properties").ParseChildValue("application.process.id = ").Trim('"')
            }
        }
}

<#
    .SYNOPSIS
    Gets all Pulse Audio input devices. (See `pactl list sources` for details)

    .PARAMETER Name
    The name of the desired source, or a pattern to match the name against.

    .OUTPUTS
    A list of PulseAudioSources matching the provided pattern, or all sources if no name was specified.
#>
function Get-PASource {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Name
    )
    pactl list sources |
        Split-IndentedData |
        ForEach-Object {
            [PulseAudioSource] @{
                Index = $_.ParseValue("Source #")
                Name = $_.ParseChildValue("Name: ")
                Description = $_.ParseChildValue("Description: ")
            }
        } |
        # Do not filter on $Name if it is not set
        Where-Object { -not $Name -or $_.Name -like $Name }
}


<#
    .SYNOPSIS
    Gets all applications receiving audio from Pulse Audio input devices. (See `pactl list source-outputs` for details)

    .OUTPUTS
    A list of PulseAudioSourceOutputs.
#>
function Get-PASourceOutput {
    pactl list source-outputs |
        Split-IndentedData |
        ForEach-Object {
            [PulseAudioSourceOutput] @{
                Index = $_.ParseValue("Source Output #")
                ApplicationName = $_.FindChild("Properties").ParseChildValue("application.name = ").Trim('"')
                BinaryName = $_.FindChild("Properties").ParseChildValue("application.process.binary = ").Trim('"')
                ProcessId = $_.FindChild("Properties").ParseChildValue("application.process.id = ").Trim('"')
            }
        }
}

<#
    .SYNOPSIS
    Sets the Pulse Audio sink being used by the specified application. (See `pactl move-sink-input` for details)

    .PARAMETER PASink
    The PulseAudioSink to be used, or the name of the sink.

    .PARAMETER PAInput
    The PulseAudioSinkInput to be moved, or the index of the sink input.

    .INPUTS
    See parameter PAInput.

    .OUTPUTS
    None
#>
function Set-PAInputSink {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $PASink,
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]
        $PAInput
    )
    # Because the test dot-sources PADataStructs.ps1 separately, the -is operator cannot be used
    # here because the type handle is not the same
    if ($PASink.GetType().Name -eq 'PulseAudioSink') {
        $PASinkName = $PASink.Name
    } else {
        $PASinkName = [string] $PASink
    }

    if ($PAInput.GetType().Name -eq 'PulseAudioSinkInput') {
        $PAInputIndex = $PAInput.Index
    } else {
        $PAInputIndex = [int] $PAInput
    }

    $output = pactl move-sink-input $PAInputIndex $PASinkName
    if ($output) {            
        throw "Could not move input $PAInputIndex to $PASinkName`: $output"
    }
}

<#
    .SYNOPSIS
    Sets the default Pulse Audio sink that will be used when an application starts. (See `pactl set-default-sink` for details)

    .PARAMETER PASink
    The PulseAudioSink to be used, or the name of the sink.

    .INPUTS
    See parameter PASink.

    .OUTPUTS
    None
#>
function Set-DefaultPASink {
    [CmdletBinding()]
    err
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]
        $PASink
    )
    # Because the test dot-sources PADataStructs.ps1 separately, the -is operator cannot be used
    # here because the type handle is not the same
    if ($PASink.GetType().Name -eq 'PulseAudioSink') {
        $PASinkName = $PASink.Name
    } else {
        $PASinkName = [string] $PASink
    }

    $output = pactl set-default-sink $PASinkName
    if ($output) {            
        throw "Could not set default sink to $PASinkName`: $output"
    }
}

Export-ModuleMember -Function Get-PACard
Export-ModuleMember -Function Set-PACardProfile
Export-ModuleMember -Function Get-PASink
Export-ModuleMember -Function Get-PASinkInput
Export-ModuleMember -Function Get-PASource
Export-ModuleMember -Function Get-PASourceOutput
Export-ModuleMember -Function Set-PAInputSink
Export-ModuleMember -Function Set-DefaultPASink
