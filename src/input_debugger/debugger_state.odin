package input

import "core:fmt"

import rl "vendor:raylib"

import game "../game"
import rl_platform "../raylib_platform"

VcrRecording :: struct {}

VcrPaused :: struct {
	paused_index: int,
}

VcrPlayback :: struct {
	current_index: int,
}

PlaybackState :: union {
	VcrRecording,
	VcrPaused,
	VcrPlayback,
}


VcrState :: struct {
	frame_history:           FrameHistory,
	state:                   PlaybackState,
	has_loaded_all_playback: bool,
}

FrameHistory :: [dynamic]game.UserInput

InputDebuggerState :: struct {
	writer:   GameInputWriter,
	reader:   GameInputReader,
	frame:    game.FrameInput,
	playback: VcrState,
}

input_debugger_setup :: proc(state: ^InputDebuggerState) {
	state.playback.frame_history = make([dynamic]game.UserInput, 0, 1024 * 128)
	state.playback.state = VcrRecording{}
}

input_debugger_teardown :: proc(state: ^InputDebuggerState) {
	delete(state.playback.frame_history)
}

input_debugger_query_if_recording :: proc(state: ^InputDebuggerState) -> bool {
	return state.playback.state == VcrRecording{}
}

input_get_frame_history :: proc(state: ^InputDebuggerState) -> FrameHistory {
	return state.playback.frame_history
}


read_write_frame :: proc(state: ^InputDebuggerState) -> GameInputError {
	switch s in state.playback.state {
	case VcrRecording:
		return record_input(state)
	case VcrPlayback:
		if state.playback.has_loaded_all_playback {
			rl.DrawText("Playback Finished", 10, 30, 20, rl.RED)
		} else {
			rl.DrawText("Playback", 10, 30, 20, rl.RED)
		}

		return playback_input(state)
	case VcrPaused:
	}
	return nil
}

input_debugger_toggle_playback :: proc(state: ^InputDebuggerState) -> (err: GameInputError) {
	switch s in state.playback.state {
	case VcrRecording:
		return toggle_playback(state)
	case VcrPlayback:
		return toggle_recording(state)
	case VcrPaused:
	}
	return nil
}
@(private)
playback_input :: proc(state: ^InputDebuggerState) -> (err: GameInputError) {
	new_frame := game.UserInput{}
	new_frame, err = game_input_reader_read_input(&state.reader)
	if err != nil {
		if err == .NoMoreFrames {
			state.playback.has_loaded_all_playback = true
			return nil
		}
		return err
	}
	append(&state.playback.frame_history, new_frame)
	state.frame.last_frame = state.frame.current_frame
	state.frame.current_frame = new_frame
	return
}

@(private)
record_input :: proc(state: ^InputDebuggerState) -> (err: GameInputError) {
	state.frame = rl_platform.update_frame(state.frame)
	err = game_input_writer_insert_frame(&state.writer, state.frame)
	if err != nil {
		return err
	}
	rl.DrawText("Recording", 10, 30, 20, rl.RED)
	return
}

@(private)
toggle_recording :: proc(state: ^InputDebuggerState) -> (err: GameInputError) {
	game_input_reader_close(&state.reader)
	err = game_input_writer_open(&state.writer)
	if err != nil {
		return
	}
	state.frame = rl_platform.update_frame(game.FrameInput{})
	game_input_writer_insert_frame(&state.writer, state.frame)
	rl.SetTargetFPS(30)
	state.playback.state = VcrRecording{}
	clear(&state.playback.frame_history)
	return
}

@(private)
toggle_playback :: proc(state: ^InputDebuggerState) -> (err: GameInputError) {
	new_frame := game.UserInput{}

	game_input_writer_close(&state.writer)
	err = game_input_reader_open(&state.reader)
	if err != nil {
		return err
	}

	state.frame = game.FrameInput{}
	new_frame, err = game_input_reader_read_input(&state.reader)
	if err != nil {
		return err
	}

	append(&state.playback.frame_history, new_frame)
	state.frame.current_frame = new_frame
	rl.SetTargetFPS(120)
	state.playback.state = VcrPlayback{0}

	return
}
