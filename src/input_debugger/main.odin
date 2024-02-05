package input

import "core:fmt"
import "core:math"
import "core:os"

import game "../game"
import rl_platform "../raylib_platform"
import rl "vendor:raylib"


panel_rect := rl.Rectangle{0, 0, 400, 450}
panel_content_rect := rl.Rectangle{20, 40, 1_500, 10_000}
panel_view := rl.Rectangle{}
panel_scroll := rl.Vector2{99, -20}
// We are going to write out the frames into a file, the zeroth iteration will
// follow bad form, and not even write in a header with a version, however, after
// this we will immediately resovle this problem before bringing it to the game
// [x] Write the inputs to a file 
// [ ] Hitting input displays on the screen which input from Kenney assets, it will color gray is not hit, red if hit
// [ ] Generate a new file every time the apps starts up
// [ ] Create a raygui list of files in the logs directory
// [ ] Allow selecting a file to play back
// [ ] Display the same keys being hit on the playback side

draw_gui :: proc(frame: game.FrameInput) {
	grid_rect := rl.Rectangle {
		panel_rect.x + panel_scroll.x,
		panel_rect.y + panel_scroll.y,
		panel_content_rect.width + 12,
		panel_content_rect.height + 12,
	}
	rl.GuiScrollPanel(panel_rect, nil, panel_content_rect, &panel_scroll, &panel_view)
	{
		rl.BeginScissorMode(
			cast(i32)(panel_rect.x),
			cast(i32)(panel_rect.y),
			cast(i32)(panel_rect.width - 12),
			cast(i32)(panel_rect.height - 12),
		)
		defer rl.EndScissorMode()
		rl.GuiGrid(grid_rect, nil, 16, 3, nil)
		text := fmt.ctprintf("Frame: %v", frame.current_frame)
		text_width := cast(f32)(rl.MeasureText(text, 12)) + 20
		panel_content_rect.width = math.max(text_width, panel_content_rect.width)

		rl.DrawText(text, cast(i32)(grid_rect.x + 5), cast(i32)(grid_rect.y + 20), 12, rl.MAROON)
	}
}

main :: proc() {
	rl.InitWindow(800, 450, "Input Debugger")
	rl.SetTargetFPS(30.0)
	defer rl.CloseWindow()

	panel_rect.x = 800 - panel_rect.width


	file_handle, err := os.open(
		"./logs/input.log",
		os.O_WRONLY | os.O_APPEND | os.O_CREATE | os.O_TRUNC,
	)
	if err != os.ERROR_NONE {
		fmt.printf("Error: %v\n", err)
		return
	}
	defer os.close(file_handle)


	frame := rl_platform.update_frame(game.FrameInput{})
	write_size, write_err := os.write_ptr(
		file_handle,
		&frame.current_frame,
		size_of(frame.current_frame),
	)
	if write_err != os.ERROR_NONE {
		fmt.printf("Error: %v\n", write_err)
		return
	}

	for {
		frame = rl_platform.update_frame(frame)
		write_size, write_err = os.write_ptr(
			file_handle,
			&frame.current_frame,
			size_of(frame.current_frame),
		)
		if write_err != os.ERROR_NONE {
			fmt.printf("Error: %v\n", write_err)
			return
		}

		if rl.WindowShouldClose() {
			break
		}


		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground(rl.RAYWHITE)

		draw_gui(frame)
		rl.DrawText(fmt.ctprintf("P(%v)", panel_scroll), 10, 10, 20, rl.MAROON)
	}
}
