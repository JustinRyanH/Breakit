package input

import rl "vendor:raylib"

import game "../game"


ButtonInputRep :: struct {
	name:    string,
	pressed: bool,
	pos:     rl.Vector2,
	scale:   f32,
	texture: rl.Texture2D,
}

input_rep_draw_all :: proc(rep: ^ButtonInputRep) {
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
