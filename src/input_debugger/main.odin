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
	scale:   f32,
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
	button_rep.scale = 1
	return
}

draw_button_input_rep :: proc(rep: ^ButtonInputRep) {
	texture := rep.texture
	if rep.pressed {
		rl.DrawTextureEx(texture, rep.pos, 0.0, rep.scale, rl.GREEN)
	} else {
		rl.DrawTextureEx(texture, rep.pos, 0.0, rep.scale, rl.RED)
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

input_rep_create_all :: proc() {
	space_button := load_inupt_rep(
		"space",
		"assets/textures/keyboard/keyboard_space.png",
		rl.Vector2{80, 100},
	)
	space_button.scale = 1.25

	left_button := load_inupt_rep(
		"left",
		"assets/textures/keyboard/keyboard_arrow_left.png",
		rl.Vector2{150, 115},
	)
	left_button.scale = 0.8
	right_button := load_inupt_rep(
		"right",
		"assets/textures/keyboard/keyboard_arrow_right.png",
		rl.Vector2{195, 115},
	)
	right_button.scale = 0.8
	append(&input_reps, space_button)
	append(&input_reps, left_button)
	append(&input_reps, right_button)
}

input_rep_cleanup_all :: proc() {
	for _, i in input_reps {
		rl.UnloadTexture(input_reps[i].texture)
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

	input_rep_create_all()
	defer input_rep_cleanup_all()
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
