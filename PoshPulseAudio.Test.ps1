BeforeAll {
    Import-Module ./PoshPulseAudio.psm1

    $testdata = @{}
    foreach($child in (Get-ChildItem $dataFolder -Filter "*.txt")) {
        $testdata[$child.BaseName] = Get-Content $child
    }

    InModuleScope PoshPulseAudio {
        Mock pactl {
            $testdata["cards"]
        } -ParameterFilter { ($args -join " ") -eq "list cards" }
    }
}

Describe 'Get-PulseAudioCards' {
    It 'Gets all pulse audio cards' {
        Get-PulseAudioCards | Should -Be $testdata["cards"]
    }
}