package input

import rl "vendor:raylib"

import game "../game"
import rl_platform "../raylib_platform"

InputVCRState :: enum {
	Recording,
	Playback,
	FinishedPlayback,
}

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
	writer:    GameInputWriter,
	reader:    GameInputReader,
	frame:     game.FrameInput,
	vcr_state: InputVCRState,
	playback:  VcrState,
}

input_debugger_setup :: proc(db_state: ^InputDebuggerState) {
	db_state.playback.frame_history = make([dynamic]game.UserInput, 0, 1024 * 128)
	db_state.vcr_state = .Recording
}

input_debugger_teardown :: proc(db_state: ^InputDebuggerState) {
	delete(db_state.playback.frame_history)
}

input_get_frame_history :: proc(db_state: ^InputDebuggerState) -> FrameHistory {
	return db_state.playback.frame_history
}


read_write_frame :: proc(db_state: ^InputDebuggerState) -> GameInputError {
	switch s in db_state.playback.state {
	case VcrRecording:
	case VcrPlayback:
	case VcrPaused:
	}
	switch db_state.vcr_state {
	case .Recording:
		db_state.frame = rl_platform.update_frame(db_state.frame)
		err := game_input_writer_insert_frame(&db_state.writer, db_state.frame)
		if err != nil {
			return err
		}
		rl.DrawText("Recording", 10, 30, 20, rl.RED)
	case .Playback:
		new_frame, err := game_input_reader_read_input(&db_state.reader)
		if err != nil {
			if err == .NoMoreFrames {
				db_state.vcr_state = .FinishedPlayback
				return nil
			}
			return err
		}
		append(&db_state.playback.frame_history, new_frame)
		db_state.frame.last_frame = db_state.frame.current_frame
		db_state.frame.current_frame = new_frame
		rl.DrawText("Playback", 10, 30, 20, rl.RED)
	case .FinishedPlayback:
		rl.DrawText("Playback Finished", 10, 30, 20, rl.RED)
	}
	return nil
}

read_write_toggle :: proc(state: ^InputDebuggerState) -> (err: GameInputError) {
	new_frame := game.UserInput{}

	switch state.vcr_state {
	case .Recording:
		game_input_writer_close(&state.writer)
		err := game_input_reader_open(&state.reader)
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
		state.vcr_state = .Playback
		state.playback.state = VcrPlayback{0}
	case .Playback, .FinishedPlayback:
		game_input_reader_close(&state.reader)
		err = game_input_writer_open(&state.writer)
		if err != nil {
			return err
		}
		state.frame = rl_platform.update_frame(game.FrameInput{})
		game_input_writer_insert_frame(&state.writer, state.frame)
		rl.SetTargetFPS(30)
		state.vcr_state = .Recording
		state.playback.state = VcrRecording{}
		clear(&state.playback.frame_history)
	}
	return nil
}
