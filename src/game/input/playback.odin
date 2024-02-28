package input

Recording :: struct {
	index: int,
}

Replay :: struct {
	index:            int,
	last_frame_index: int,
	active:           bool,
}


ReplayTo :: struct {
	index:            int,
	target_index:     int,
	last_frame_index: int,
	was_active:       bool,
}

Playback :: union {
	Recording,
	Replay,
	ReplayTo,
}

PlaybackError :: enum {
	StreamOverflow,
}

InputError :: union {
	PlaybackError,
}
