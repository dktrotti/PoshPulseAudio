BeforeDiscovery {
    $Global:testdata = @{}
    foreach($child in (Get-ChildItem $PSScriptRoot/testdata -Filter "*.txt")) {
        $Global:testdata[$child.BaseName] = Get-Content $child
    }
}

BeforeAll {
    Remove-Module PoshPulseAudio
    Import-Module ./PoshPulseAudio.psm1

    InModuleScope PoshPulseAudio {
        Mock pactl {
            throw "pactl interation not mocked: pactl $($args -join " ")"
        }
    }
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
        $cards = Get-PulseAudioCards
        
        $cards.Count | Should -Be 3
        $cards[0].Name | Should -Be "alsa_card.usb-FiiO_DigiHug_USB_Audio-01"
        $cards[0].Driver | Should -Be "module-alsa-card.c"
        $cards[1].Name | Should -Be "alsa_card.usb-C-Media_Electronics_Inc._USB_Audio_Device-00"
        $cards[1].Driver | Should -Be "module-alsa-card.c"
        $cards[2].Name | Should -Be "alsa_card.pci-0000_2d_00.1"
        $cards[2].Driver | Should -Be "module-alsa-card.c"
    }

    It 'Returns empty when no cards are found' {
        "an unimplemented test" | Should -Be "implemented"
    }

    It 'Gets a pulse audio card by name' {
        "an unimplemented test" | Should -Be "implemented"
    }

    It 'Returns empty when named card is not found' {
        "an unimplemented test" | Should -Be "implemented"
    }

    It 'Gets a pulse audio card by wildcard name match' {
        "an unimplemented test" | Should -Be "implemented"
    }

    It 'Returns multiple cards when multiple matches are found' {
        "an unimplemented test" | Should -Be "implemented"
    }

    It 'Returns empty when no matching cards are found' {
        "an unimplemented test" | Should -Be "implemented"
    }

    It 'Populates profiles correctly' {
        "an unimplemented test" | Should -Be "implemented"
    }

    It 'Populates the active profile correctly' {
        "an unimplemented test" | Should -Be "implemented"
    }
}