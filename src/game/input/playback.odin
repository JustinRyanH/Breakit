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
	active:           bool,
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

FileHeader :: struct {
	version:     u32le,
	header_size: u32le,
	frame_size:  u32le,
}

get_file_header :: proc() -> FileHeader {
	header := FileHeader{}

	header.version = 1
	header.header_size = size_of(FileHeader)
	header.frame_size = size_of(UserInput)

	return header
}
