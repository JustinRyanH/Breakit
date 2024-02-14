package input

import "core:fmt"
import math "core:math/linalg"
import "core:os"
import "core:strings"
import "core:testing"
import "core:time"

import game "../game"
import mu "../microui"
import rl_platform "../raylib_platform"

InputParsingError :: enum {
	BadHeader,
	InvalidHeaderVersion,
	InvalidHeaderSize,
	NoMoreFrames,
}

GameInputFileError :: enum {
	HandleClosedOrReadOnly,
	FileNotOpen,
	NoAccess,
	MismatchWriteSize,
	NotInReadMode,
	NotInWriteMode,
	SystemError,
}

GameInputError :: union {
	InputParsingError,
	GameInputFileError,
}

FrameHistory :: [dynamic]game.UserInput

VcrRecording :: struct {
	current_frame: game.FrameInput,
}

VcrPlayback :: struct {
	current_index: int,
	active:        bool,
}

VcrLoop :: struct {
	current_index: int,
	start_index:   int,
	end_index:     int,
	active:        bool,
}

PlaybackState :: union {
	VcrRecording,
	VcrPlayback,
	VcrLoop,
}

VcrState :: struct {
	frame_history:           FrameHistory,
	state:                   PlaybackState,
	has_loaded_all_playback: bool,
	loop_min:                mu.Real,
	loop_max:                mu.Real,
}

InputFileSystem :: struct {
	current_file: string,
	io:           GameInputIO,
}

InputDebuggerState :: struct {
	ifs:      InputFileSystem,
	playback: VcrState,
}

InputFileHeader :: struct {
	version:     u16le,
	header_size: u32le,
	did_finish:  bool,
	frame_count: u64le,
}

GameInputReader :: struct {
	file_path:   string,
	file_handle: os.Handle,
	is_open:     bool,

	// Meta Data about file
	header:      InputFileHeader,
}

GameInputWriter :: struct {
	file_path:   string,
	file_handle: os.Handle,
	is_open:     bool,

	// Meta Data about file
	header:      InputFileHeader,
}

GameInputIO :: union {
	GameInputReader,
	GameInputWriter,
}


////////////////////////////////
// Input Debugger
////////////////////////////////

input_debugger_setup :: proc(state: ^InputDebuggerState) {
	state.playback.frame_history = make([dynamic]game.UserInput, 0, 1024 * 128)
	state.playback.state = VcrRecording{}
}

input_debugger_teardown :: proc(state: ^InputDebuggerState) {
	delete(state.playback.frame_history)
}

input_debugger_load_file :: proc(
	state: ^InputDebuggerState,
	file: string,
) -> (
	err: GameInputError,
) {
	input_file_set_new_file(&state.ifs, file)
	clear_frame_history(state)
	clear(&state.playback.frame_history)
	state.playback.has_loaded_all_playback = false

	switch v in state.playback.state {
	case VcrRecording:
		return .NotInReadMode
	case VcrPlayback:
		_, err = input_file_begin_read(&state.ifs)
		if err != nil {
			return
		}
		state.playback.state = VcrPlayback{0, v.active}
	case VcrLoop:
		_, err = input_file_begin_read(&state.ifs)
		if err != nil {
			return
		}
		state.playback.state = VcrLoop{0, 0, 0, v.active}
	}
	return
}

input_debugger_query_if_recording :: proc(state: ^InputDebuggerState) -> bool {
	_, ok := state.playback.state.(VcrRecording)
	return ok
}

input_debugger_query_current_frame :: proc(
	state: ^InputDebuggerState,
) -> (
	frame_input: game.FrameInput,
) {
	switch v in state.playback.state {
	case VcrRecording:
		frame_input = v.current_frame
	case VcrPlayback:
		return frame_at_index(state, v.current_index)
	case VcrLoop:
		return frame_at_index(state, v.current_index)
	}
	return
}

input_debugger_load_next_frame :: proc(
	state: ^InputDebuggerState,
	input: game.UserInput,
) -> GameInputError {
	switch s in &state.playback.state {
	case VcrRecording:
		s.current_frame = game.frame_next(s.current_frame, input)
		err := input_file_write_frame(&state.ifs, s.current_frame)
		if err != nil {
			return nil
		}
		return nil
	case VcrPlayback:
		if state.playback.has_loaded_all_playback {
		} else {
		}
		return playback_input(state)
	case VcrLoop:
		return playback_input(state)
	}
	return nil
}

input_debugger_toggle_playback :: proc(state: ^InputDebuggerState) -> GameInputError {
	switch _ in state.playback.state {
	case VcrRecording:
		return toggle_playback(state)
	case VcrPlayback:
		return toggle_recording(state)
	case VcrLoop:
		return toggle_recording(state)
	}
	return nil
}


////////////////////////
// InputFileSystem
////////////////////////

// We are going to free the previous file,
// so let's start with a copy of empty string instead of a static
input_file_setup :: proc(ifs: ^InputFileSystem) {
	ifs.current_file = strings.clone("")
}

input_file_new_file :: proc(ifs: ^InputFileSystem) {
	old_str := ifs.current_file
	now := time.to_unix_seconds(time.now())
	log_name := fmt.tprintf("logs/file-%d.ilog", now)
	ifs.current_file = strings.clone(log_name)
	delete(old_str)
}

input_file_set_new_file :: proc(ifs: ^InputFileSystem, new_file: string) {
	delete(ifs.current_file)
	ifs.current_file = strings.clone(new_file)
}

input_file_begin_write :: proc(
	ifs: ^InputFileSystem,
) -> (
	writer: GameInputWriter,
	err: GameInputError,
) {
	game_input_close(&ifs.io)

	new_writer := game_input_writer_create(ifs.current_file)
	err = game_input_writer_open(&new_writer)
	ifs.io = new_writer
	return new_writer, err
}

input_file_begin_read :: proc(
	ifs: ^InputFileSystem,
) -> (
	reader: GameInputReader,
	err: GameInputError,
) {
	game_input_close(&ifs.io)

	new_reader := game_input_reader_create(ifs.current_file)
	err = game_input_reader_open(&new_reader)
	ifs.io = new_reader
	return
}

input_file_write_frame :: proc(
	ifs: ^InputFileSystem,
	new_frame: game.FrameInput,
) -> GameInputError {
	writer, ok := ifs.io.(GameInputWriter)
	if ok {
		return game_input_writer_insert_frame(&writer, new_frame)
	}
	return .NotInReadMode
}

input_file_read_input :: proc(
	ifs: ^InputFileSystem,
) -> (
	input: game.UserInput,
	err: GameInputError,
) {
	reader, ok := ifs.io.(GameInputReader)
	if ok {
		return game_input_reader_read_input(&reader)
	}
	return game.UserInput{}, .NotInWriteMode
}


////////////////////////////////
// GameInputIO functions
////////////////////////////////

game_input_close :: proc(io: ^GameInputIO) {
	switch v in io {
	case GameInputWriter:
		game_input_writer_close(&v)
	case GameInputReader:
		game_input_reader_close(&v)
	}
}


////////////////////////////////
// GameInputReader functions
////////////////////////////////


game_input_reader_create :: proc(file_path: string) -> (reader: GameInputReader) {
	reader.file_path = file_path
	return
}

game_input_reader_open :: proc(reader: ^GameInputReader) -> GameInputError {
	handle, err := os.open(reader.file_path, os.O_RDONLY)
	if err == os.ERROR_NONE {
		reader.file_handle = handle
		reader.is_open = true

		size, read_err := os.read_ptr(reader.file_handle, &reader.header, size_of(reader.header))
		if read_err != os.ERROR_NONE {
			return .SystemError
		}
		if size != size_of(reader.header) {
			return .BadHeader
		}
		if reader.header.version != 1 {
			return .InvalidHeaderVersion
		}

		if reader.header.header_size != size_of(reader.header) {
			return .InvalidHeaderSize
		}

		return nil
	}
	when ODIN_OS == .Darwin {
	}
	return .SystemError

}

game_input_reader_close :: proc(reader: ^GameInputReader) -> bool {
	when ODIN_OS == .Darwin {
		success := os.close(reader.file_handle)
		if (success) {
			reader.is_open = false
		}
		return true
	} else when ODIN_OS == .Windows {
		err := os.close(reader.file_handle)
		if (err != os.ERROR_NONE) {
			reader.is_open = false
			return true
		}

	}
	return false
}

game_input_reader_read_input :: proc(
	reader: ^GameInputReader,
) -> (
	new_frame: game.UserInput,
	err: GameInputError,
) {
	if !reader.is_open {
		err = .FileNotOpen
		return
	}

	read_size, read_err := os.read_ptr(reader.file_handle, &new_frame, size_of(game.UserInput))
	if read_err != os.ERROR_NONE {
		when ODIN_OS == .Darwin {
			if read_err == os.EBADF {
				err = .HandleClosedOrReadOnly
				return
			}
			err = .SystemError
			return
		} else when ODIN_OS == .Windows {
			if read_err == os.ERROR_EOF {
				err = .NoMoreFrames
				return
			}
			err = .SystemError
			return
		}
	}
	if read_size == 0 {
		err = .NoMoreFrames
		return
	}
	if read_size != size_of(new_frame) {
		err = .MismatchWriteSize
		return
	}

	return
}

////////////////////////////////
// GameInputWriter functions
////////////////////////////////

// Create Input Reader, does not open the file
game_input_writer_create :: proc(file_path: string) -> (writer: GameInputWriter) {
	writer.file_path = file_path
	writer.header.version = 1
	writer.header.header_size = size_of(InputFileHeader)
	return
}

// Oepn the Handle to the Writer
game_input_writer_open :: proc(writer: ^GameInputWriter) -> GameInputError {
	handle, err := os.open(
		writer.file_path,
		os.O_WRONLY | os.O_APPEND | os.O_CREATE | os.O_TRUNC,
		0o644,
	)
	if err == os.ERROR_NONE {
		writer.file_handle = handle
		writer.is_open = true
		write_size, err := os.write_ptr(writer.file_handle, &writer.header, size_of(writer.header))
		if err != os.ERROR_NONE {
			return .SystemError
		}

		if write_size != size_of(writer.header) {
			return .MismatchWriteSize
		}
		return nil
	}

	return .SystemError
}

// Return true if the file was closed successfully
game_input_writer_close :: proc(writer: ^GameInputWriter) -> bool {
	when ODIN_OS == .Darwin {
		success := os.close(writer.file_handle)
		if (success) {
			writer.is_open = false
		}
		return true
	} else when ODIN_OS == .Windows {
		err := os.close(writer.file_handle)
		if (err != os.ERROR_NONE) {
			writer.is_open = false
			return true
		}
	}
	return false
}

game_input_writer_insert_frame :: proc(
	writer: ^GameInputWriter,
	frame: game.FrameInput,
) -> GameInputError {
	if !writer.is_open {
		return .FileNotOpen
	}
	current_frame := frame.current_frame

	write_size, err := os.write_ptr(writer.file_handle, &current_frame, size_of(current_frame))
	if err != os.ERROR_NONE {
		return .SystemError
	}

	if write_size != size_of(current_frame) {
		return .MismatchWriteSize
	}
	return nil
}

////////////////////////////////
// Private Functions
////////////////////////////////

@(private)
toggle_recording :: proc(state: ^InputDebuggerState) -> (err: GameInputError) {
	input_file_new_file(&state.ifs)
	_, err = input_file_begin_write(&state.ifs)

	clear_frame_history(state)
	state.playback.state = VcrRecording{game.FrameInput{}}
	return
}

@(private)
clear_frame_history :: proc(state: ^InputDebuggerState) {
	clear(&state.playback.frame_history)
	state.playback.has_loaded_all_playback = false
}

@(private)
toggle_playback :: proc(state: ^InputDebuggerState) -> (err: GameInputError) {
	_, err = input_file_begin_read(&state.ifs)
	new_frame := game.UserInput{}

	state.playback.state = VcrPlayback{0, false}
	return
}


@(private = "file")
frame_at_index :: proc(state: ^InputDebuggerState, idx: int) -> game.FrameInput {
	if frame_history_len(state) == 0 {
		return game.FrameInput{}
	}

	previous_frame := state.playback.frame_history[idx - 1] if idx > 0 else game.UserInput{}
	current_frame := state.playback.frame_history[idx]
	return game.FrameInput{previous_frame, current_frame, false}
}


@(private)
frame_history_len :: proc(state: ^InputDebuggerState) -> int {
	return len(state.playback.frame_history)
}


@(private)
step_playback :: proc(state: ^InputDebuggerState, v: ^VcrPlayback) {
	len_of_history := frame_history_len(state)
	if len_of_history == 0 {
		return
	}
	v.current_index += 1
	if v.current_index >= len_of_history {
		v.current_index = 0
		v.active = false
	}
}

@(private)
step_loop :: proc(state: ^InputDebuggerState, v: ^VcrLoop) {
	len_of_history := frame_history_len(state)
	if len_of_history == 0 {
		return
	}
	v.current_index += 1
	if v.current_index > v.end_index {
		v.current_index = v.start_index
	}
}

@(private)
playback_input :: proc(state: ^InputDebuggerState) -> GameInputError {
	if !state.playback.has_loaded_all_playback {
		for i := 0; i < 30; i += 1 {
			new_frame, err := input_file_read_input(&state.ifs)
			if err == .NoMoreFrames {
				state.playback.has_loaded_all_playback = true
				break
			} else if err != nil {
				return nil
			} else {
				append(&state.playback.frame_history, new_frame)
			}
		}
		loop, ok := &state.playback.state.(VcrLoop)
		if ok {
			loop.end_index = len(state.playback.frame_history) - 1
			state.playback.loop_max = cast(mu.Real)loop.end_index
		}
	}
	#partial switch v in &state.playback.state {
	case VcrPlayback:
		if !v.active {
			return nil
		}
		step_playback(state, &v)
	case VcrLoop:
		if !v.active {
			return nil
		}
		step_loop(state, &v)
	}

	return nil
}

////////////////////////////////
// GUI
////////////////////////////////

input_debugger_mui :: proc(ctx: ^mu.Context, state: ^InputDebuggerState) {
	mu.begin(ctx)
	defer mu.end(ctx)

	window_width: i32 = 400
	window_height: i32 = 450

	if !input_debugger_query_if_recording(state) {
		if mu.window(
			   ctx,
			   "Input Recording",
			   {800 - window_width, 0, window_width, window_height},
			   {.NO_CLOSE},
		   ) {

			input_debugger_playback(ctx, state)
			input_debugger_files(ctx, state)
		}
	}
}


input_debugger_files :: proc(ctx: ^mu.Context, state: ^InputDebuggerState) {
	mu.layout_row(ctx, {-1})
	mu.label(ctx, fmt.tprintf("Loaded File: %s", state.ifs.current_file))

	header_res := mu.header(ctx, "Input Files", {.CLOSED})
	if .ACTIVE not_in header_res {
		log_dir, err := os.open("logs")

		if err != os.ERROR_NONE {
			fmt.printf("Errno: %v", err)
			return
		}
		defer os.close(log_dir)

		files, dir_err := os.read_dir(log_dir, 50, context.temp_allocator)

		if dir_err != os.ERROR_NONE {
			fmt.printf("Errno: %v", err)
			return
		}

		for file in files {
			mu.layout_row(ctx, {-1})
			button_ref := mu.button(ctx, fmt.tprintf("Load %s", file.name))
			if .SUBMIT in button_ref {
				new_file := fmt.tprintf("logs/%s", file.name)
				err := input_debugger_load_file(state, new_file)
				if err != nil {
					fmt.printf("Err: %v", err)
					return
				}
			}
		}

		return
	}
}

input_debugger_playback :: proc(ctx: ^mu.Context, state: ^InputDebuggerState) {
	res := mu.header(ctx, "Playback Controls", {.EXPANDED})
	if .ACTIVE not_in res {
		return
	}
	fh_len := len(state.playback.frame_history)

	#partial switch v in &state.playback.state {
	case VcrPlayback:
		mu.layout_row(ctx, {-1})
		mu.label(ctx, fmt.tprintf("Single Playback Frame(%d)", v.current_index))

		mu.layout_row(ctx, {50, 50, 50, 50})
		if mu.button(ctx, "LOOP", .NONE) == {.SUBMIT} {

			state.playback.state = VcrLoop{0, 0, fh_len - 1, v.active}
			state.playback.loop_min = cast(f32)0
			state.playback.loop_max = cast(f32)fh_len - 1
		}

		txt := "PAUSE" if v.active else "RESUME"
		if mu.button(ctx, txt, .NONE) == {.SUBMIT} {
			v.active = !v.active
		}

		if !v.active {
			if mu.button(ctx, "STEP >", .NONE) == {.SUBMIT} {
				step_playback(state, &v)
			}
		}

		if mu.button(ctx, "RESTART", .NONE) == {.SUBMIT} {
			v.current_index = 0
		}

	case VcrLoop:
		mu.layout_row(ctx, {-1})
		mu.label(ctx, fmt.tprintf("Loop Playback Frame( %d )", v.current_index))

		mu.layout_row(ctx, {50, 75, 75, 50, 50, 50})
		if mu.button(ctx, "Back", .NONE) == {.SUBMIT} {
			state.playback.state = VcrPlayback{v.current_index, v.active}
		}


		slider_res := mu.slider(
			ctx,
			&state.playback.loop_min,
			0,
			cast(mu.Real)v.end_index - 1 if v.end_index != 0 else 0,
			1,
			"Start Frame: %.0f",
		)
		if .CHANGE in slider_res {
			v.start_index = cast(int)state.playback.loop_min
		}
		slider_res = mu.slider(
			ctx,
			&state.playback.loop_max,
			cast(mu.Real)v.start_index + 1 if fh_len != 0 else 0,
			cast(mu.Real)fh_len,
			1,
			"End Frame: %.0f",
		)
		if .CHANGE in slider_res {
			v.end_index = cast(int)state.playback.loop_max
		}

		txt := "PAUSE" if v.active else "RESUME"
		if mu.button(ctx, txt, .NONE) == {.SUBMIT} {
			v.active = !v.active
		}

		if !v.active {
			if mu.button(ctx, "STEP >", .NONE) == {.SUBMIT} {
				step_loop(state, &v)
			}
		}

		if mu.button(ctx, "RESTART", .NONE) == {.SUBMIT} {
			v.current_index = v.start_index
		}
	}
}

////////////////////////////////
// Tests
////////////////////////////////

@(test)
test_input_writer :: proc(t: ^testing.T) {
	current_frame := game.UserInput{}
	current_frame.meta.frame_id = 1
	current_frame.meta.frame_delta = 1 / 60
	current_frame.meta.screen_width = 100
	current_frame.meta.screen_height = 120
	current_frame.mouse.pos = math.Vector2f32{15, 15}
	current_frame.keyboard.space_down = true

	frame_input := game.FrameInput{}
	frame_input.current_frame = current_frame

	writer := game_input_writer_create("bin/test.log")
	reader := game_input_reader_create("bin/test.log")
	err := game_input_writer_open(&writer)
	testing.expect(t, err == nil, fmt.tprintf("Expected No Error, Got: %v", err))

	defer {
		if writer.is_open {
			game_input_writer_close(&writer)
			testing.expect(t, writer.is_open == false, "Expected Writer to be Closed")
		}
		if reader.is_open {
			game_input_reader_close(&reader)
			testing.expect(t, writer.is_open == false, "Expected Reader to be Closed")
		}
	}
	defer {
		delete_err := os.remove(writer.file_path)
		testing.expect(
			t,
			delete_err == os.ERROR_NONE,
			fmt.tprintf("Unable to delete test file: #%v", delete_err),
		)
	}

	testing.expect(t, err == nil, fmt.tprintf("Expected No Error, Go Error: %v", err))

	err = game_input_writer_insert_frame(&writer, frame_input)
	testing.expect(t, err == nil, fmt.tprintf("Expected No Error, Got: %v", err))

	game_input_writer_close(&writer)

	err = game_input_reader_open(&reader)
	testing.expect(t, err == nil, fmt.tprintf("Expected No Error, Got: %v", err))
	testing.expect(t, reader.header.version == 1, "Expected Version to be 1")
	testing.expect(
		t,
		reader.header.header_size == size_of(InputFileHeader),
		fmt.tprintf(
			"Expected Header Size to be %v, Got: ",
			reader.header.header_size,
			size_of(InputFileHeader),
		),
	)

	input, read_err := game_input_reader_read_input(&reader)
	testing.expect(t, read_err == nil, fmt.tprintf("Expected No Error, Got: %v", read_err))
	testing.expect(t, input == current_frame, "Expected Frame to be the same")
}
