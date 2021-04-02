BeforeAll {
    Import-Module ./PoshPulseAudio.psm1

    InModuleScope PoshPulseAudio {
        Mock pactl {
            "card1"
        } -ParameterFilter { ($args -join " ") -eq "list short cards" }
    }
}

Describe 'Get-PulseAudioCards' {
    It 'Gets all pulse audio cards' {
        Get-PulseAudioCards | Should -Be "card1"
    }
}
