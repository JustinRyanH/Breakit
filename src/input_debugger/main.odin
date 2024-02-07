package input

import "core:fmt"
import math "core:math/linalg"
import "core:os"

import game "../game"
import rl_platform "../raylib_platform"
import rl "vendor:raylib"

ScreenWidth :: 800
ScreenHeight :: 450

input_reps: [dynamic]ButtonInputRep

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

ButtonInputRep :: struct {
	name:    string,
	pressed: bool,
	pos:     rl.Vector2,
	texture: rl.Texture2D,
}

load_inupt_rep :: proc(
	name: string,
	path: cstring,
	pos: rl.Vector2,
) -> (
	button_rep: ButtonInputRep,
) {
	button_rep.name = name
	button_rep.pos = pos
	button_rep.texture = rl.LoadTexture(path)
	return
}

unload_input_rep :: proc(rep: ^ButtonInputRep) {
	rl.UnloadTexture(rep.texture)
}

draw_button_input_rep :: proc(rep: ^ButtonInputRep) {
	texture := rep.texture
	if rep.pressed {
		rl.DrawTexture(texture, cast(i32)(rep.pos.x), cast(i32)(rep.pos.y), rl.GREEN)
	} else {
		rl.DrawTexture(texture, cast(i32)(rep.pos.x), cast(i32)(rep.pos.y), rl.GRAY)
	}
}

input_rep_record_input :: proc(rep: ^ButtonInputRep) {
	if rep.name == "space" {
		rep.pressed = rl.IsKeyDown(.SPACE)
	}
	if rep.name == "left" {
		rep.pressed = rl.IsKeyDown(.LEFT)
	}
	if rep.name == "right" {
		rep.pressed = rl.IsKeyDown(.RIGHT)
	}
}

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
	rl.InitWindow(ScreenWidth, ScreenHeight, "Input Debugger")
	rl.SetTargetFPS(30.0)
	defer rl.CloseWindow()

	input_reps = make([dynamic]ButtonInputRep)
	defer delete(input_reps)

	space_button := load_inupt_rep(
		"space",
		"assets/textures/keyboard/keyboard_space.png",
		rl.Vector2{100, 100},
	)
	defer unload_input_rep(&space_button)
	append(&input_reps, space_button)

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
		rl.ClearBackground(rl.BLACK)

		for _, i in input_reps {
			input_rep_record_input(&input_reps[i])
			draw_button_input_rep(&input_reps[i])
		}
		draw_gui(frame)

		rl.DrawText(fmt.ctprintf("P(%v)", panel_scroll), 10, 10, 20, rl.MAROON)
	}
}
