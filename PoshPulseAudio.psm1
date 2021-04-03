class IndentedDataItem {
    [string] $Value
    [IndentedDataItem[]] $Children

    [IndentedDataItem] FindChild([string] $pattern) {
        return $this.Children | Where-Object { $_.Value -match $pattern } | Select-Object -First 1
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
                    $currentObject.Children = $childLines | ForEach-Object { $_.TrimStart("`t") } | Split-IndentedData
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
        if ($currentObject) {
            $currentObject.Children = $childLines | ForEach-Object { $_.TrimStart("`t") } | Split-IndentedData
            # output the last object to the stream
            $currentObject
        }
    }
}

class PulseAudioCard {
    [string] $Name
    [string] $Driver
}

function Get-PulseAudioCards {
    pactl list cards |
        Split-IndentedData |
        ForEach-Object {
            # TODO: Using FindChild and -replace is awkward, find a better way
            [PulseAudioCard] @{
                Name = $_.FindChild("^Name:.*").Value -replace "Name: "
                Driver = $_.FindChild("^Driver:.*").Value -replace "Driver: "
            }
        }
}

Export-ModuleMember -Function Get-PulseAudioCards