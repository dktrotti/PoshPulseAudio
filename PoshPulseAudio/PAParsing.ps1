class IndentedDataItem {
    [string] $Value
    [IndentedDataItem[]] $Children

    [IndentedDataItem] FindChild([string] $pattern) {
        return $this.Children | Where-Object { $_.Value -match $pattern } | Select-Object -First 1
    }

    [string] ParseChildValue([string] $prefix) {
        return $this.FindChild("^$prefix.*").Value -replace $prefix
    }

    [string] ParseValue([string] $prefix) {
        return $this.Value -replace $prefix
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
        function parseChildLines([string[]] $childLines) {
            $childLines | Where-Object { $_ -ne "" } | ForEach-Object { $_.substring(1) } | Split-IndentedData
        }

        $currentObject = $null
        $childLines = @()
    }
    process {
        switch -regex ($inputData) {
            '^(\S.*)' {
                if ($null -ne $currentObject) {
                    $currentObject.Children = parseChildLines $childLines
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
            $currentObject.Children = parseChildLines $childLines
            # output the last object to the stream
            $currentObject
        }
    }
}
