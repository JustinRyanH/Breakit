package input

import "core:fmt"
import math "core:math/linalg"
import "core:os"

import mu "vendor:microui"
import rl "vendor:raylib"

import game "../game"
import rl_platform "../raylib_platform"

ScreenWidth :: 800
ScreenHeight :: 450

input_reps: [dynamic]ButtonInputRep
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

playback_gui :: proc(ctx: ^mu.Context) {

	mu.begin(ctx)
	defer mu.end(ctx)

	window_width: i32 = 400

	if db_state.vcr_state == .Playback || db_state.vcr_state == .FinishedPlayback {
		if mu.window(
			   ctx,
			   "Playback State",
			   {800 - window_width, 150, window_width, 200},
			   {.NO_CLOSE, .NO_RESIZE},
		   ) {
			frame_history := input_get_frame_history(&db_state)
			for frame in frame_history {
				font := ctx.style.font
				label := fmt.tprintf("%v", frame)

				text_width := ctx.text_width(font, label)
				mu.layout_row(ctx, {text_width, -1})
				mu.label(ctx, label)

			}
		}
	}
}


main :: proc() {
	rl.InitWindow(ScreenWidth, ScreenHeight, "Input Debugger")
	rl.SetTargetFPS(30.0)
	defer rl.CloseWindow()

	input_debugger_setup(&db_state)
	defer input_debugger_teardown(&db_state)

	ctx := new(mu.Context)
	defer free(ctx)

	mu.init(ctx)

	rl_platform.setup_raylib_mui(ctx)
	defer rl_platform.destroy_raylib_mui()

	db_state.writer = game_input_writer_create("logs/input.log")
	db_state.reader = game_input_reader_create("logs/input.log")
	db_state.vcr_state = .Recording

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

	db_state.frame = rl_platform.update_frame(game.FrameInput{})
	game_input_writer_insert_frame(&db_state.writer, db_state.frame)

	for {
		rl_platform.load_input(ctx)
		playback_gui(ctx)

		err := read_write_frame()
		if err != nil {
			fmt.printf("Error: %v", err)
			return
		}

		if rl.IsKeyPressed(.F5) {
			err = read_write_toggle()
			if err != nil {
				fmt.printf("Error: %v", err)
				return
			}
		}

		if rl.WindowShouldClose() {
			break
		}


		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground(rl.BLACK)

		for _, i in input_reps {
			input_rep_record_input(&input_reps[i], db_state.frame)
			input_rep_draw_all(&input_reps[i])
		}

		rl_platform.render_ui(ctx)
	}
}
