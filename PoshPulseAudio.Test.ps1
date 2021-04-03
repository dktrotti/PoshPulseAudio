BeforeDiscovery {
    $Global:testdata = @{}
    foreach($child in (Get-ChildItem $PSScriptRoot/testdata -Filter "*.txt")) {
        $Global:testdata[$child.BaseName] = Get-Content $child
    }
}

BeforeAll {
    Remove-Module PoshPulseAudio -ErrorAction SilentlyContinue
    Import-Module ./PoshPulseAudio.psm1

    InModuleScope PoshPulseAudio {
        Mock pactl {
            throw "pactl interation not mocked: pactl $($args -join " ")"
        }
    }
}

Describe 'Get-PACard' {
    BeforeAll {
        InModuleScope PoshPulseAudio {
            Mock pactl {
                $Global:testdata["cards"]
            } -ParameterFilter { ($args -join " ") -eq "list cards" }
        }
    }

    It 'Gets all pulse audio cards' {
        $cards = Get-PACard
        
        $cards.Count | Should -Be 3
        $cards[0].Index | Should -Be 0
        $cards[0].Name | Should -Be "alsa_card.usb-FiiO_DigiHug_USB_Audio-01"
        $cards[0].Driver | Should -Be "module-alsa-card.c"
        $cards[1].Index | Should -Be 1
        $cards[1].Name | Should -Be "alsa_card.usb-C-Media_Electronics_Inc._USB_Audio_Device-00"
        $cards[1].Driver | Should -Be "module-alsa-card.c"
        $cards[2].Index | Should -Be 2
        $cards[2].Name | Should -Be "alsa_card.pci-0000_2d_00.1"
        $cards[2].Driver | Should -Be "module-alsa-card.c"
    }

    It 'Gets a pulse audio card by name' {
        $card = Get-PACard -Name "alsa_card.pci-0000_2d_00.1"
        
        $card.Index | Should -Be 2
        $card.Name | Should -Be "alsa_card.pci-0000_2d_00.1"
    }

    It 'Returns empty when named card is not found' {
        $card = Get-PACard -Name "alsa_card.usb-DNE"

        $card | Should -BeNullOrEmpty
    }

    It 'Gets a pulse audio card by wildcard name match' {
        $cards = Get-PACard -Name "alsa_card.usb-FiiO_DigiHug_USB_Audio-*"
        
        $cards.Count | Should -Be 1
        $cards[0].Name | Should -Be "alsa_card.usb-FiiO_DigiHug_USB_Audio-01"
        $cards[0].Index | Should -Be 0
    }

    It 'Returns multiple cards when multiple matches are found' {
        $cards = Get-PACard -Name "alsa_card.usb-*"
        
        $cards.Count | Should -Be 2
        $cards[0].Name | Should -Be "alsa_card.usb-FiiO_DigiHug_USB_Audio-01"
        $cards[0].Index | Should -Be 0
        $cards[1].Name | Should -Be "alsa_card.usb-C-Media_Electronics_Inc._USB_Audio_Device-00"
        $cards[1].Index | Should -Be 1
    }

    It 'Returns empty when no matching cards are found' {
        $cards = Get-PACard -Name "alsa_card.usb-DNE*"

        $cards.Count | Should -Be 0
    }

    It 'Populates profiles correctly' {
        $card = Get-PACard -Name "alsa_card.usb-FiiO_DigiHug_USB_Audio-01"

        $card.Profiles.Count | Should -Be 9

        $card.Profiles[0].SymbolicName | Should -Be "input:analog-stereo"
        $card.Profiles[0].DisplayName | Should -Be "Analog Stereo Input"
        $card.Profiles[0].SinkCount | Should -Be 0
        $card.Profiles[0].SourceCount | Should -Be 1
        $card.Profiles[0].Priority | Should -Be 65
        $card.Profiles[0].Available | Should -BeTrue

        $card.Profiles[1].SymbolicName | Should -Be "input:iec958-stereo"
        $card.Profiles[1].DisplayName | Should -Be "Digital Stereo (IEC958) Input"
        $card.Profiles[1].SinkCount | Should -Be 0
        $card.Profiles[1].SourceCount | Should -Be 1
        $card.Profiles[1].Priority | Should -Be 55
        $card.Profiles[1].Available | Should -BeFalse

        $card.Profiles[8].SymbolicName | Should -Be "off"
        $card.Profiles[8].DisplayName | Should -Be "Off"
        $card.Profiles[8].SinkCount | Should -Be 0
        $card.Profiles[8].SourceCount | Should -Be 0
        $card.Profiles[8].Priority | Should -Be 0
        $card.Profiles[8].Available | Should -BeTrue
    }

    It 'Populates the active profile correctly' {
        $card = Get-PACard -Name "alsa_card.usb-FiiO_DigiHug_USB_Audio-01"

        $card.ActiveProfile.SymbolicName | Should -Be "output:iec958-stereo"
    }
}

Describe 'Set-PACardProfile' {
    BeforeAll {
        InModuleScope PoshPulseAudio {
            Mock pactl {} -ParameterFilter { $args[0] -eq "set-card-profile" }
        }
    }

    It 'Sets the active theme by card name' {
        Set-ItResult -Skipped -Because "unimplemented"
    }

    It 'Sets the active theme by card object' {
        Set-ItResult -Skipped -Because "unimplemented"
    }

    It 'Sets the active theme using card name from pipeline' {
        Set-ItResult -Skipped -Because "unimplemented"
    }

    It 'Sets the active theme using card object from pipeline' {
        Set-ItResult -Skipped -Because "unimplemented"
    }

    It 'Throws an error when pactl outputs error message' {
        Set-ItResult -Skipped -Because "unimplemented"
    }
}