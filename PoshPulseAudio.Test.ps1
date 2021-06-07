BeforeDiscovery {
    $Global:testdata = @{}
    foreach($child in (Get-ChildItem $PSScriptRoot/testdata -Filter "*.txt")) {
        $Global:testdata[$child.BaseName] = Get-Content $child
    }
}

BeforeAll {
    Remove-Module PoshPulseAudio -ErrorAction SilentlyContinue
    Import-Module ./PoshPulseAudio.psm1

    . $PSScriptRoot/PADataStructs.ps1

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
        $cardName = 'card1'
        $profileName = 'profile1'
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUserDeclaredVarsMoreThanAssignments', '')]
        $paCard = [PulseAudioCard] @{ Name = $cardName }
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUserDeclaredVarsMoreThanAssignments', '')]
        $paProfile = [PulseAudioProfile] @{ SymbolicName = $profileName }

        InModuleScope PoshPulseAudio {
            Mock pactl {} -ParameterFilter { $args[0] -eq "set-card-profile" }
        }
    }

    It 'Sets the active profile using names' {
        Set-PACardProfile -PACard $cardName -PAProfile $profileName 

        Should -Invoke pactl -ModuleName PoshPulseAudio -Times 1 -ParameterFilter { $args[1] -eq $cardName -and $args[2] -eq $profileName }
    }

    It 'Sets the active profile using objects' {
        Set-PACardProfile -PACard $paCard -PAProfile $paProfile 

        Should -Invoke pactl -ModuleName PoshPulseAudio -Times 1 -ParameterFilter { $args[1] -eq $cardName -and $args[2] -eq $profileName }
    }

    It 'Sets the active profile using a card from the pipeline' {
        $paCard | Set-PACardProfile -PAProfile $paProfile 

        Should -Invoke pactl -ModuleName PoshPulseAudio -Times 1 -ParameterFilter { $args[1] -eq $cardName -and $args[2] -eq $profileName }
    }

    It 'Throws an error when pactl outputs error message' {
        InModuleScope PoshPulseAudio {
            Mock pactl { "Failure: No such entity" } -ParameterFilter { $args[0] -eq "set-card-profile" }
        }

        { Set-PACardProfile -PACard $paCard -PAProfile $paProfile } |
            Should -Throw "Could not set profile for $cardName to $profileName`: Failure: No such entity"
    }
}

Describe 'Get-PASink' {
    BeforeAll {
        InModuleScope PoshPulseAudio {
            Mock pactl {
                $Global:testdata["sinks"]
            } -ParameterFilter { ($args -join " ") -eq "list sinks" }
        }
    }

    It 'Gets all sinks' {
        $sinks = Get-PASink
        
        $sinks.Count | Should -Be 2
        $sinks[0].Index | Should -Be 1
        $sinks[0].Name | Should -Be "alsa_output.usb-FiiO_DigiHug_USB_Audio-01.iec958-stereo"
        $sinks[0].Description | Should -Be "Fiio E10 Digital Stereo (IEC958)"
        $sinks[1].Index | Should -Be 26
        $sinks[1].Name | Should -Be "alsa_output.pci-0000_2d_00.1.hdmi-stereo-extra2"
        $sinks[1].Description | Should -Be "TU104 HD Audio Controller Digital Stereo (HDMI 3)"
    }

    It 'Gets a pulse audio sink by name' {
        $sink = Get-PASink -Name "alsa_output.usb-FiiO_DigiHug_USB_Audio-01.iec958-stereo"
        
        $sink.Index | Should -Be 1
        $sink.Name | Should -Be "alsa_output.usb-FiiO_DigiHug_USB_Audio-01.iec958-stereo"
    }

    It 'Returns empty when named sink is not found' {
        $sink = Get-PASink -Name "alsa_output.usb-FiiO_DigiHug_USB_Audio-01.DNE"

        $sink | Should -BeNullOrEmpty
    }

    It 'Gets a pulse audio sink by wildcard name match' {
        $sinks = Get-PASink -Name "alsa_output.usb-FiiO_DigiHug_USB_Audio-01.*"
        
        $sinks.Count | Should -Be 1
        $sinks[0].Name | Should -Be "alsa_output.usb-FiiO_DigiHug_USB_Audio-01.iec958-stereo"
        $sinks[0].Index | Should -Be 1
    }

    It 'Returns multiple sinks when multiple matches are found' {
        $sinks = Get-PASink -Name "alsa_output.*"
        
        $sinks.Count | Should -Be 2
        $sinks[0].Index | Should -Be 1
        $sinks[1].Index | Should -Be 26
    }

    It 'Returns empty when no matching sinks are found' {
        $sinks = Get-PASink -Name "alsa_output.DNE*"

        $sinks.Count | Should -Be 0
    }
}

Describe 'GetPASinkInput' {
    BeforeAll {
        InModuleScope PoshPulseAudio {
            Mock pactl {
                $Global:testdata["sinkinputs"]
            } -ParameterFilter { ($args -join " ") -eq "list sink-inputs" }
        }
    }

    It 'Gets all sink inputs' {
        $sinks = Get-PASinkInput
        
        $sinks.Count | Should -Be 3
        $sinks[0].Index | Should -Be 24
        $sinks[0].ApplicationName | Should -Be "speech-dispatcher-espeak-ng"
        $sinks[0].BinaryName | Should -Be "sd_espeak-ng"
        $sinks[0].ProcessId | Should -Be 15245
        $sinks[1].Index | Should -Be 25
        $sinks[1].ApplicationName | Should -Be "speech-dispatcher-dummy"
        $sinks[1].BinaryName | Should -Be "sd_dummy"
        $sinks[1].ProcessId | Should -Be 15251
        $sinks[2].Index | Should -Be 267
        $sinks[2].ApplicationName | Should -Be "WEBRTC VoiceEngine"
        $sinks[2].BinaryName | Should -Be "Discord"
        $sinks[2].ProcessId | Should -Be 5307
    }
}

Describe 'GetPASource' {
    BeforeAll {
        InModuleScope PoshPulseAudio {
            Mock pactl {
                $Global:testdata["sources"]
            } -ParameterFilter { ($args -join " ") -eq "list sources" }
        }
    }

    It 'Gets all sources' {
        $sources = Get-PASource
        
        $sources.Count | Should -Be 3
        $sources[0].Index | Should -Be 1
        $sources[0].Name | Should -Be "alsa_output.usb-FiiO_DigiHug_USB_Audio-01.iec958-stereo.monitor"
        $sources[0].Description | Should -Be "Monitor of Fiio E10 Digital Stereo (IEC958)"
        $sources[1].Index | Should -Be 2
        $sources[1].Name | Should -Be "alsa_input.usb-C-Media_Electronics_Inc._USB_Audio_Device-00.mono-fallback"
        $sources[1].Description | Should -Be "Audio Adapter (Unitek Y-247A) Mono"
        $sources[2].Index | Should -Be 28
        $sources[2].Name | Should -Be "alsa_output.pci-0000_2d_00.1.hdmi-stereo-extra2.monitor"
        $sources[2].Description | Should -Be "Monitor of TU104 HD Audio Controller Digital Stereo (HDMI 3)"
    }

    It 'Gets a pulse audio source by name' {
        $source = Get-PASource -Name "alsa_input.usb-C-Media_Electronics_Inc._USB_Audio_Device-00.mono-fallback"
        
        $source.Index | Should -Be 2
        $source.Name | Should -Be "alsa_input.usb-C-Media_Electronics_Inc._USB_Audio_Device-00.mono-fallback"
    }

    It 'Returns empty when named source is not found' {
        $source = Get-PASource -Name "alsa_input.usb-C-Media_Electronics_Inc.DNE"

        $source | Should -BeNullOrEmpty
    }

    It 'Gets a pulse audio source by wildcard name match' {
        $sources = Get-PASource -Name "alsa_output.usb-FiiO_*"
        
        $sources.Count | Should -Be 1
        $sources[0].Index | Should -Be 1
        $sources[0].Name | Should -Be "alsa_output.usb-FiiO_DigiHug_USB_Audio-01.iec958-stereo.monitor"
    }

    It 'Returns multiple sources when multiple matches are found' {
        $sources = Get-PASource -Name "alsa_output.*"
        
        $sources.Count | Should -Be 2
        $sources[0].Index | Should -Be 1
        $sources[1].Index | Should -Be 28
    }

    It 'Returns empty when no matching sources are found' {
        $sources = Get-PASource -Name "alsa_output.DNE*"

        $sources.Count | Should -Be 0
    }
}

Describe 'GetPASourceOutput' {
    BeforeAll {
        InModuleScope PoshPulseAudio {
            Mock pactl {
                $Global:testdata["sourceoutputs"]
            } -ParameterFilter { ($args -join " ") -eq "list source-outputs" }
        }
    }

    It 'Gets all source outputs' {
        $sources = Get-PASourceOutput
        
        $sources.Count | Should -Be 1
        $sources[0].Index | Should -Be 13
        $sources[0].ApplicationName | Should -Be "WEBRTC VoiceEngine"
        $sources[0].BinaryName | Should -Be "Discord"
        $sources[0].ProcessId | Should -Be 5307
    }
}

Describe 'SetPAInputSink' {
    BeforeAll {
        $sinkName = 'sink1'
        $inputIndex = 2
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUserDeclaredVarsMoreThanAssignments', '')]
        $paSink = [PulseAudioSink] @{ Name = $sinkName }
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUserDeclaredVarsMoreThanAssignments', '')]
        $paSinkInput = [PulseAudioSinkInput] @{ Index = $inputIndex }

        InModuleScope PoshPulseAudio {
            Mock pactl {} -ParameterFilter { $args[0] -eq "move-sink-input" }
        }
    }

    It 'Moves the input to the sink using primitives' {
        Set-PAInputSink -PASink $sinkName -PAInput $inputIndex 

        Should -Invoke pactl -ModuleName PoshPulseAudio -Times 1 -ParameterFilter { $args[1] -eq $inputIndex -and $args[2] -eq $sinkName }
    }

    It 'Moves the input to the sink using objects' {
        Set-PAInputSink -PASink $paSink -PAInput $paSinkInput 

        Should -Invoke pactl -ModuleName PoshPulseAudio -Times 1 -ParameterFilter { $args[1] -eq $inputIndex -and $args[2] -eq $sinkName }
    }

    It 'Moves the input using an input from the pipeline' {
        $paSinkInput | Set-PAInputSink -PASink $paSink 

        Should -Invoke pactl -ModuleName PoshPulseAudio -Times 1 -ParameterFilter { $args[1] -eq $inputIndex -and $args[2] -eq $sinkName }
    }

    It 'Throws an error when pactl outputs error message' {
        InModuleScope PoshPulseAudio {
            Mock pactl { "Failure: No such entity" } -ParameterFilter { $args[0] -eq "move-sink-input" }
        }

        { Set-PAInputSink -PASink $paSink -PAInput $paSinkInput } |
            Should -Throw "Could not move input $inputIndex to $sinkName`: Failure: No such entity"
    }
}