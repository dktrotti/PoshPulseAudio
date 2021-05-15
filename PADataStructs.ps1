class PulseAudioCard {
    [int] $Index
    [string] $Name
    [string] $Driver
    [PulseAudioProfile[]] $Profiles
    [PulseAudioProfile] $ActiveProfile

    [string] ToString() {
        return ConvertTo-Json $this
    }
}

class PulseAudioProfile {
    [string] $SymbolicName
    [string] $DisplayName
    [int] $SinkCount
    [int] $SourceCount
    [int] $Priority
    [bool] $Available

    [string] ToString() {
        return ConvertTo-Json $this
    }
}

class PulseAudioSink {
    [int] $Index
    [string] $Name
    [string] $Description

    [string] ToString() {
        return ConvertTo-Json $this
    }
}

class PulseAudioSinkInput {
    [int] $Index
    [string] $ApplicationName
    [string] $BinaryName
    [int] $ProcessId

    [string] ToString() {
        return ConvertTo-Json $this
    }
}