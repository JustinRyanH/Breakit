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
// We are going to write out the frames into a file, the zeroth iteration will
// follow bad form, and not even write in a header with a version, however, after
// this we will immediately resovle this problem before bringing it to the game
// [x] Write the inputs to a file 
// [x] Hitting input displays on the screen which input from Kenney assets, it will color gray is not hit, red if hit
// [ ] Display the same keys being hit on the playback side
// [ ] Generate a new file every time the apps starts up
// [ ] Create a raygui list of files in the logs directory
// [ ] Allow selecting a file to play back

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

input_rep_record_input :: proc(rep: ^ButtonInputRep, frame: game.FrameInput) {
	if rep.name == "space" {
		rep.pressed = game.input_is_space_down(frame)
	}
	if rep.name == "left" {
		rep.pressed = game.input_is_left_arrow_down(frame)
	}
	if rep.name == "right" {
		rep.pressed = game.input_is_right_arrow_down(frame)
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


main :: proc() {
	is_recording := true
	has_frames := true
	if (os.exists("logs/input.log")) {
		os.remove("logs/input.log")
	}
	input_writer := game_input_writer_create("logs/input.log")
	input_reader := game_input_reader_create("logs/input.log")

	err := game_input_writer_open(&input_writer)
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
	game_input_writer_insert_frame(&input_writer, frame)

	for {
		if is_recording {
			frame = rl_platform.update_frame(frame)
			err := game_input_writer_insert_frame(&input_writer, frame)
			if err != nil {
				fmt.printf("Error writing to file: %v\n", err)
				return
			}
		} else if has_frames {
			new_frame, err := game_input_reader_read_input(&input_reader)
			if err != nil {
				if err == .NoMoreFrames {
					has_frames = false
					continue
				}
				fmt.printf("Error reading from input file: %v\n", err)
				return
			}
			frame.last_frame = frame.current_frame
			frame.current_frame = new_frame
		}

		if !is_recording && !has_frames {
			rl.DrawText("Used all frame", 10, 30, 20, rl.RED)
		}


		if rl.IsKeyPressed(.F5) {
			if is_recording {
				game_input_writer_close(&input_writer)
				err = game_input_reader_open(&input_reader)
				if err != nil {
					fmt.printf("Error opening input file: %v\n", err)
					return
				}
				frame := game.FrameInput{}
				new_frame, err := game_input_reader_read_input(&input_reader)
				if err != nil {
					fmt.printf("Error opening input file: %v\n", err)
					return
				}
				frame.current_frame = new_frame
				is_recording = false
				has_frames = true
			} else {
				game_input_reader_close(&input_reader)
				err = game_input_writer_open(&input_writer)
				if err != nil {
					fmt.printf("Error opening input file: %v\n", err)
					return
				}
				frame = rl_platform.update_frame(game.FrameInput{})
				game_input_writer_insert_frame(&input_writer, frame)
				is_recording = true

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
			draw_button_input_rep(&input_reps[i])
		}
	}
}
