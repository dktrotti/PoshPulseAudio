function Get-PulseAudioCards {
    pactl list short cards
}

Export-ModuleMember -Function Get-PulseAudioCards