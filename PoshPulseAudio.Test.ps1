BeforeDiscovery {
    $Global:testdata = @{}
    foreach($child in (Get-ChildItem $PSScriptRoot/testdata -Filter "*.txt")) {
        $Global:testdata[$child.BaseName] = Get-Content $child
    }
}

BeforeAll {
    Import-Module ./PoshPulseAudio.psm1
}

Describe 'Get-PulseAudioCards' {
    BeforeAll {
        InModuleScope PoshPulseAudio {
            Mock pactl {
                $Global:testdata["cards"]
            } -ParameterFilter { ($args -join " ") -eq "list cards" }
        }
    }

    It 'Gets all pulse audio cards' {
        Get-PulseAudioCards | Should -Be $Global:testdata["cards"]
    }
}