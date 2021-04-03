class IndentedDataItem {
    [string] $Value
    [IndentedDataItem[]] $Children

    [IndentedDataItem] FindChild([string] $pattern) {
        return $this.Children | Where-Object { $_.Value -match $pattern } | Select-Object -First 1
    }

    [string] ToString() {
        return "Value: $($this.Value) Children: [$($this.Children)]"
    }
}

function Split-IndentedData {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline=$true)]
        [string]
        $inputData
    )
    begin {
        $currentObject = $null
        $childLines = @()
    }
    process {
        switch -regex ($inputData) {
            '^(\S.*)' {
                if ($null -ne $currentObject) {
                    $currentObject.Children = $childLines |
                        Where-Object { $_ -ne "" } |
                        ForEach-Object { $_.substring(1) } |
                        Split-IndentedData
                    # output the object to the stream
                    $currentObject
                }
                $currentObject = [IndentedDataItem] @{
                    Value = $matches.1
                }
                $childLines = @()
                continue
            }

            default {
                # append the current line to the children
                $childLines += $_
            }
        }
    }
    end {
        # TODO: This block duplicates the above, find a way to combine them
        if ($currentObject) {
            $currentObject.Children = $childLines |
                Where-Object { $_ -ne "" } |
                ForEach-Object { $_.substring(1) } |
                Split-IndentedData
            # output the last object to the stream
            $currentObject
        }
    }
}

class PulseAudioCard {
    [int] $Index
    [string] $Name
    [string] $Driver
    [PulseAudioProfile[]] $Profiles
    [PulseAudioProfile] $ActiveProfile
}

class PulseAudioProfile {
    [string] $SymbolicName
    [string] $DisplayName
    [int] $SinkCount
    [int] $SourceCount
    [int] $Priority
    [bool] $Available
}

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
        [Parameter(Mandatory=$true)]
        [string]
        $Card,
        [Parameter(Mandatory=$true)]
        [string]
        $Profile
    )
    pactl set-card-profile $Card $Profile
}

Export-ModuleMember -Function Get-PACard
Export-ModuleMember -Function Set-PACardProfile