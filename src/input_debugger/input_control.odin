package input

import "core:fmt"
import "core:math"
import "core:os"
import "core:strings"
import "core:time"

import game "../game"
import mu "../microui"
import rl_platform "../raylib_platform"

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


input_get_frame_history :: proc(state: ^InputDebuggerState) -> FrameHistory {
	return state.playback.frame_history
}


input_debugger_load_next_frame :: proc(state: ^InputDebuggerState, input: game.UserInput) -> GameInputError {
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
