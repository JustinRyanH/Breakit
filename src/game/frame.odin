package game

import math "core:math/linalg"
import "core:testing"

FrameMeta :: struct {
	frame_id:      int,
	frame_delta:   f32,
	screen_width:  f32,
	screen_height: f32,
}

MouseInput :: struct {
	pos:        math.Vector2f32,
	left_down:  bool,
	right_down: bool,
}

KeyboardInput :: struct {
	left_down:  bool,
	right_down: bool,
	space_down: bool,
}

// Tracked User State Input
UserInput :: struct {
	meta:     FrameMeta,
	mouse:    MouseInput,
	keyboard: KeyboardInput,
}


// Information about current Frame,
// read by game and used for playback recording
FrameInput :: struct {
	current_frame: UserInput,
	last_frame:    UserInput,
}


///////////////////////////////////////////
// User Input Functions
///////////////////////////////////////////

get_frame_time :: proc(input: FrameInput) -> f32 {
	return input.current_frame.meta.frame_delta
}

get_mouse_position :: proc(input: FrameInput) -> math.Vector2f32 {
	return input.current_frame.mouse.pos
}

get_mouse_delta :: proc(input: FrameInput) -> math.Vector2f32 {
	return input.current_frame.mouse.pos - input.last_frame.mouse.pos
}

// Is the Right Arrow down this frame
is_right_arrow_down :: proc(input: FrameInput) -> bool {
	return input.current_frame.keyboard.right_down
}

// Was the Right Arrow pressed the framae before
was_right_arrow_pressed :: proc(input: FrameInput) -> bool {
	return was_pressed(
		input.last_frame.keyboard.right_down,
		input.current_frame.keyboard.right_down,
	)
}


// Is the Left Arrow down this frame
is_left_arrow_down :: proc(input: FrameInput) -> bool {
	return input.current_frame.keyboard.left_down
}

// Was the Left Arrow pressed the frame before
was_left_arrow_pressed :: proc(input: FrameInput) -> bool {
	return was_pressed(input.last_frame.keyboard.left_down, input.current_frame.keyboard.left_down)
}

// Is the Space key down this frame
is_space_down :: proc(input: FrameInput) -> bool {
	return input.current_frame.keyboard.space_down
}

// Was the Space key pressed the frame before
was_space_pressed :: proc(input: FrameInput) -> bool {
	return was_pressed(
		input.last_frame.keyboard.space_down,
		input.current_frame.keyboard.space_down,
	)
}

///////////////////////////////////////////
// Helpers
///////////////////////////////////////////

was_pressed :: proc(previous_state, current_state: bool) -> bool {
	return !current_state && previous_state
}


///////////////////////////////////////////
// Testing
///////////////////////////////////////////

@(test)
test_is_key_down :: proc(t: ^testing.T) {
	meta := FrameMeta{0, 1.0 / 60.0, 500, 700}

	keyboard_p := KeyboardInput{false, false, false}
	keyboard_c := KeyboardInput{false, true, false}

	last_frame := UserInput{meta, MouseInput{}, keyboard_p}
	current_frame := UserInput{meta, MouseInput{}, keyboard_c}

	input := FrameInput{current_frame, last_frame}


	testing.expect(t, is_right_arrow_down(input), "Right Arrow should be down")
	testing.expect(t, !is_left_arrow_down(input), "Left Arrow should not be down")
	testing.expect(t, !is_space_down(input), "Space should not be down")
}

@(test)
test_was_key_pressed :: proc(t: ^testing.T) {
	meta := FrameMeta{0, 1.0 / 60.0, 500, 700}

	keyboard_p := KeyboardInput{false, true, true}
	keyboard_c := KeyboardInput{false, false, true}

	last_frame := UserInput{meta, MouseInput{}, keyboard_p}
	current_frame := UserInput{meta, MouseInput{}, keyboard_c}

	input := FrameInput{current_frame, last_frame}

	testing.expect(t, was_right_arrow_pressed(input), "Right Arrow should have been pressed")
	testing.expect(t, !was_left_arrow_pressed(input), "Left Arrow should not be pressed")
	testing.expect(t, !was_space_pressed(input), "Space should not be pressed")
}
