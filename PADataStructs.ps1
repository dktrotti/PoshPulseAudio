# TODO: Implement ToString on these types
class PulseAudioCard {
    [int] $Index
    [string] $Name
    [string] $Driver
    [PulseAudioProfile[]] $Profiles
    [PulseAudioProfile] $ActiveProfile
}

class PulseAudioProfile {
    [string] $SymbolicName
    [string] $DisplayName
    [int] $SinkCount
    [int] $SourceCount
    [int] $Priority
    [bool] $Available
}

class PulseAudioSink {
    [int] $Index
    [string] $Name
    [string] $Description
}