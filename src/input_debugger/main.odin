package input

import "core:fmt"
import math "core:math/linalg"
import "core:os"
import "core:strings"

import rl "vendor:raylib"

import game "../game"
import mu "../microui"
import rl_platform "../raylib_platform"
import ta "../tracking_alloc"

ScreenWidth :: 800
ScreenHeight :: 450

input_reps: [dynamic]ButtonInputRep

// We are going to write out the frames into a file, the zeroth iteration will
// follow bad form, and not even write in a header with a version, however, after
// this we will immediately resovle this problem before bringing it to the game
// [x] Write the inputs to a file 
// [x] Hitting input displays on the screen which input from Kenney assets, it will color gray is not hit, red if hit
// [x] Display the same keys being hit on the playback side
// [x] Set up Playback tools to loop, pause, and replay
// [ ] Create a mui list of files in the logs directory
// [ ] Allow selecting a file to play back


main :: proc() {
	default_allocator := context.allocator
	tracking_allocator: ta.Tracking_Allocator
	ta.tracking_allocator_init(&tracking_allocator, default_allocator)
	context.allocator = ta.allocator_from_tracking_allocator(&tracking_allocator)
	defer ta.tracking_allocator_destroy(&tracking_allocator)
	db_state := new(InputDebuggerState)

	rl.InitWindow(ScreenWidth, ScreenHeight, "Input Debugger")
	rl.SetTargetFPS(30.0)
	defer rl.CloseWindow()

	input_debugger_setup(db_state)
	defer input_debugger_teardown(db_state)

	ctx := new(mu.Context)
	defer free(ctx)

	mu.init(ctx)

	rl_platform.setup_raylib_mui(ctx)
	defer rl_platform.destroy_raylib_mui()

	db_state.writer = game_input_writer_create("logs/input.log")
	db_state.reader = game_input_reader_create("logs/input.log")
	input_file_system_setup(&db_state.ifs)

	if (os.exists("logs/input.log")) {
		os.remove("logs/input.log")
	}

	err := game_input_writer_open(&db_state.writer)
	if err != nil {
		fmt.printf("Error opening input file: %v\n", err)
		return
	}

	input_reps = make([dynamic]ButtonInputRep)
	defer delete(input_reps)

	input_rep_create_all()
	defer input_rep_cleanup_all()

	for {
		rl_platform.load_input(ctx)
		input_debugger_gui(db_state, ctx)

		if rl.IsKeyPressed(.F5) {
			err = input_debugger_toggle_playback(db_state)
			if err != nil {
				fmt.printf("Error: %v", err)
				return
			}
		}

		err := read_write_frame(db_state)
		if err != nil {
			fmt.printf("Error: %v", err)
			return
		}


		if rl.WindowShouldClose() {
			break
		}


		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground(rl.BLACK)

		for _, i in input_reps {
			current_frame := input_debugger_query_current_frame(db_state)
			input_rep_record_input(&input_reps[i], current_frame)
			input_rep_draw_all(&input_reps[i])
		}

		rl_platform.render_ui(ctx)

		free_all(context.temp_allocator)
	}
}
