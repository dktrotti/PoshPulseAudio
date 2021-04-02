function Get-PulseAudioCards {
    pactl list cards
}

Export-ModuleMember -Function Get-PulseAudioCards