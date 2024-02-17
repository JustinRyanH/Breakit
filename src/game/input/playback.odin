package input

Recording :: struct {
	index: int,
}

Replay :: struct {
	index:            int,
	last_frame_index: int,
	active:           bool,
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
