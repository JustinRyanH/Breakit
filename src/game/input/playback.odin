package input

Recording :: struct {
	index: int,
}

Replay :: struct {
	index: int,
}

Playback :: union {
	Recording,
	Replay,
}

PlaybackError :: enum {
	StreamOverflow,
}

InputError :: union {
	PlaybackError,
}
