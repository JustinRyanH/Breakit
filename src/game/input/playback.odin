package input

Recording :: struct {
	index: int,
}

Replay :: struct {
	index:            int,
	last_frame_index: int,
	active:           bool,
}

LoopState :: enum {
	Looping,
	PlayingToStartIndex,
}

Loop :: struct {
	index:            int,
	start_index:      int,
	end_index:        int,
	last_frame_index: int,
	state:            LoopState,
	start_index_data: []u8,
}

Playback :: union {
	Recording,
	Replay,
	Loop,
}

PlaybackError :: enum {
	StreamOverflow,
}

InputError :: union {
	PlaybackError,
}
