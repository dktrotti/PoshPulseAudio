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
            $activeProfileName = $_.FindChild("^Active Profile:.*").Value -replace "Active Profile: "
            # TODO: Using FindChild and -replace is awkward, find a better way
            [PulseAudioCard] @{
                Index = $_.Value -replace "Card #"
                Name = $_.FindChild("^Name:.*").Value -replace "Name: "
                Driver = $_.FindChild("^Driver:.*").Value -replace "Driver: "
                Profiles = $profiles
                ActiveProfile = $profiles | Where-Object { $_.SymbolicName -eq $activeProfileName } | Select-Object -First 1
            }
        } |
        # Do not filter on $Name if it is not set
        Where-Object { -not $Name -or $_.Name -like $Name }
}

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

function Get-PASink {
    pactl list sinks |
        Split-IndentedData |
        ForEach-Object {
            # TODO: Using FindChild and -replace is awkward, find a better way
            [PulseAudioSink] @{
                Index = $_.Value -replace "Sink #"
                Name = $_.FindChild("^Name:.*").Value -replace "Name: "
                Description = $_.FindChild("^Description:.*").Value -replace "Description: "
            }
        }
}

Export-ModuleMember -Function Get-PACard
Export-ModuleMember -Function Set-PACardProfile
Export-ModuleMember -Function Get-PASink