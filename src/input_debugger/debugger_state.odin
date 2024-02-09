package input

import rl "vendor:raylib"

import game "../game"
import rl_platform "../raylib_platform"

InputVCRState :: enum {
	Recording,
	Playback,
	FinishedPlayback,
}

FrameHistory :: [dynamic]game.UserInput

InputDebuggerState :: struct {
	writer:        GameInputWriter,
	reader:        GameInputReader,
	frame:         game.FrameInput,
	vcr_state:     InputVCRState,
	frame_history: FrameHistory,
}

input_debugger_setup :: proc(db_state: ^InputDebuggerState) {
	db_state.frame_history = make([dynamic]game.UserInput, 0, 1024 * 128)
}

input_debugger_teardown :: proc(db_state: ^InputDebuggerState) {
	delete(db_state.frame_history)
}

input_get_frame_history :: proc(db_state: ^InputDebuggerState) -> FrameHistory {
	return db_state.frame_history
}


read_write_frame :: proc() -> GameInputError {
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
		append(&db_state.frame_history, new_frame)
		db_state.frame.last_frame = db_state.frame.current_frame
		db_state.frame.current_frame = new_frame
		rl.DrawText("Playback", 10, 30, 20, rl.RED)
	case .FinishedPlayback:
		rl.DrawText("Playback Finished", 10, 30, 20, rl.RED)
	}
	return nil
}

read_write_toggle :: proc() -> (err: GameInputError) {
	new_frame := game.UserInput{}
	switch db_state.vcr_state {
	case .Recording:
		game_input_writer_close(&db_state.writer)
		err := game_input_reader_open(&db_state.reader)
		if err != nil {
			return err
		}
		db_state.frame = game.FrameInput{}
		new_frame, err = game_input_reader_read_input(&db_state.reader)
		if err != nil {
			return err
		}
		append(&db_state.frame_history, new_frame)
		db_state.frame.current_frame = new_frame
		rl.SetTargetFPS(120)
		db_state.vcr_state = .Playback
	case .Playback, .FinishedPlayback:
		game_input_reader_close(&db_state.reader)
		err = game_input_writer_open(&db_state.writer)
		if err != nil {
			return err
		}
		db_state.frame = rl_platform.update_frame(game.FrameInput{})
		game_input_writer_insert_frame(&db_state.writer, db_state.frame)
		rl.SetTargetFPS(30)
		db_state.vcr_state = .Recording
		clear(&db_state.frame_history)
	}
	return nil
}
