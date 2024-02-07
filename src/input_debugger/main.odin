package input

import "core:fmt"
import math "core:math/linalg"
import "core:os"
import rl "vendor:raylib"

import game "../game"
import rl_platform "../raylib_platform"

ScreenWidth :: 800
ScreenHeight :: 450

input_reps: [dynamic]ButtonInputRep

InputVCRState :: enum {
	Recording,
	Playback,
	FinishedPlayback,
}

InputDebuggerState :: struct {
	writer: GameInputWriter,
	reader: GameInputReader,
}

db_state: InputDebuggerState


// We are going to write out the frames into a file, the zeroth iteration will
// follow bad form, and not even write in a header with a version, however, after
// this we will immediately resovle this problem before bringing it to the game
// [x] Write the inputs to a file 
// [x] Hitting input displays on the screen which input from Kenney assets, it will color gray is not hit, red if hit
// [ ] Display the same keys being hit on the playback side
// [ ] Generate a new file every time the apps starts up
// [ ] Create a raygui list of files in the logs directory
// [ ] Allow selecting a file to play back


main :: proc() {
	db_state.writer = game_input_writer_create("logs/input.log")
	db_state.reader = game_input_reader_create("logs/input.log")
	vcr_state: InputVCRState = .Recording

	if (os.exists("logs/input.log")) {
		os.remove("logs/input.log")
	}

	err := game_input_writer_open(&db_state.writer)
	if err != nil {
		fmt.printf("Error opening input file: %v\n", err)
		return
	}

	rl.InitWindow(ScreenWidth, ScreenHeight, "Input Debugger")
	rl.SetTargetFPS(30.0)
	defer rl.CloseWindow()

	input_reps = make([dynamic]ButtonInputRep)
	defer delete(input_reps)

	input_rep_create_all()
	defer input_rep_cleanup_all()


	frame := rl_platform.update_frame(game.FrameInput{})
	game_input_writer_insert_frame(&db_state.writer, frame)

	for {
		switch vcr_state {
		case .Recording:
			frame = rl_platform.update_frame(frame)
			err := game_input_writer_insert_frame(&db_state.writer, frame)
			if err != nil {
				fmt.printf("Error writing to file: %v\n", err)
				return
			}
			rl.DrawText("Recording", 10, 30, 20, rl.RED)
		case .Playback:
			new_frame, err := game_input_reader_read_input(&db_state.reader)
			if err != nil {
				if err == .NoMoreFrames {
					vcr_state = .FinishedPlayback
					continue
				}
				fmt.printf("Error reading from input file: %v\n", err)
				return
			}
			frame.last_frame = frame.current_frame
			frame.current_frame = new_frame
			rl.DrawText("Playback", 10, 30, 20, rl.RED)
		case .FinishedPlayback:
			rl.DrawText("Playback Finished", 10, 30, 20, rl.RED)

		}

		if rl.IsKeyPressed(.F5) {
			switch vcr_state {
			case .Recording:
				game_input_writer_close(&db_state.writer)
				err = game_input_reader_open(&db_state.reader)
				if err != nil {
					fmt.printf("Error opening input file: %v\n", err)
					return
				}
				frame := game.FrameInput{}
				new_frame, err := game_input_reader_read_input(&db_state.reader)
				if err != nil {
					fmt.printf("Error opening input file: %v\n", err)
					return
				}
				frame.current_frame = new_frame
				rl.SetTargetFPS(120)
				vcr_state = .Playback
			case .Playback, .FinishedPlayback:
				game_input_reader_close(&db_state.reader)
				err = game_input_writer_open(&db_state.writer)
				if err != nil {
					fmt.printf("Error opening input file: %v\n", err)
					return
				}
				frame = rl_platform.update_frame(game.FrameInput{})
				game_input_writer_insert_frame(&db_state.writer, frame)
				rl.SetTargetFPS(30)
				vcr_state = .Recording
			}
		}


		if rl.WindowShouldClose() {
			break
		}


		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground(rl.BLACK)

		for _, i in input_reps {
			input_rep_record_input(&input_reps[i], frame)
			input_rep_draw_all(&input_reps[i])
		}
	}
}
