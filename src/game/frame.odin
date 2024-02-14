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
	debug:         bool,
}


///////////////////////////////////////////
// User Input Functions
///////////////////////////////////////////


frame_next :: proc(previous_frame: FrameInput, user_input: UserInput) -> FrameInput {
	new_frame := FrameInput{}
	new_frame.debug = previous_frame.debug
	new_frame.last_frame = previous_frame.current_frame
	new_frame.current_frame = user_input
	new_frame.current_frame.meta.frame_id = previous_frame.last_frame.meta.frame_id + 1
	return new_frame
}


frame_toggle_debug :: proc(frame: ^FrameInput) {
	frame.debug = !frame.debug
}

frame_query_debug :: proc(frame_input: FrameInput) -> bool {
	return frame_input.debug
}

// Get the amount of time for this frame
frame_query_delta :: proc(frame_input: FrameInput) -> f32 {
	return frame_input.current_frame.meta.frame_delta
}

// Returns width and height of the current frame
frame_query_dimensions :: proc(frame_input: FrameInput) -> (width, height: f32) {
	return frame_input.current_frame.meta.screen_width,
		frame_input.current_frame.meta.screen_height
}

// Get the mouse position this frame
input_mouse_position :: proc(frame_input: FrameInput) -> math.Vector2f32 {
	return frame_input.current_frame.mouse.pos
}

// Get the delta of the mouse position from the last frame
input_mouse_delta :: proc(frame_input: FrameInput) -> math.Vector2f32 {
	return frame_input.current_frame.mouse.pos - frame_input.last_frame.mouse.pos
}

// Is the Left Mouse Button down this frame
input_is_left_mouse_down :: proc(frame_input: FrameInput) -> bool {
	return frame_input.current_frame.mouse.left_down
}

// Was the Left Mouse Button pressed the frame before, not this frame
input_was_left_mouse_pressed :: proc(frame_input: FrameInput) -> bool {
	return was_pressed(
		frame_input.last_frame.mouse.left_down,
		frame_input.current_frame.mouse.left_down,
	)
}

// Is the Right Mouse Button down this frame
input_is_right_mouse_down :: proc(frame_input: FrameInput) -> bool {
	return frame_input.current_frame.mouse.right_down
}

// Was the Right Mouse Button pressed the frame before, not this frame
input_was_right_mouse_pressed :: proc(frame_input: FrameInput) -> bool {
	return was_pressed(
		frame_input.last_frame.mouse.right_down,
		frame_input.current_frame.mouse.right_down,
	)
}

// Is the Right Arrow down this frame
input_is_right_arrow_down :: proc(frame_input: FrameInput) -> bool {
	return frame_input.current_frame.keyboard.right_down
}

// Was the Right Arrow pressed the framae before, not this frame
input_was_right_arrow_pressed :: proc(frame_input: FrameInput) -> bool {
	return was_pressed(
		frame_input.last_frame.keyboard.right_down,
		frame_input.current_frame.keyboard.right_down,
	)
}

// Is the Left Arrow down this frame
input_is_left_arrow_down :: proc(frame_input: FrameInput) -> bool {
	return frame_input.current_frame.keyboard.left_down
}

// Was the Left Arrow pressed the frame before, not this frame
input_was_left_arrow_pressed :: proc(frame_input: FrameInput) -> bool {
	return was_pressed(
		frame_input.last_frame.keyboard.left_down,
		frame_input.current_frame.keyboard.left_down,
	)
}

// Is the Space key down this frame
input_is_space_down :: proc(frame_input: FrameInput) -> bool {
	return frame_input.current_frame.keyboard.space_down
}

// Was the Space key pressed the frame before, not this frame
input_was_space_pressed :: proc(frame_input: FrameInput) -> bool {
	return was_pressed(
		frame_input.last_frame.keyboard.space_down,
		frame_input.current_frame.keyboard.space_down,
	)
}

///////////////////////////////////////////
// Helpers
///////////////////////////////////////////

@(private = "file")
was_pressed :: #force_inline proc(previous_state, current_state: bool) -> bool {
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

	input := FrameInput{current_frame, last_frame, false}


	testing.expect(t, input_is_right_arrow_down(input), "Right Arrow should be down")
	testing.expect(t, !input_is_left_arrow_down(input), "Left Arrow should not be down")
	testing.expect(t, !input_is_space_down(input), "Space should not be down")
}

@(test)
test_was_key_pressed :: proc(t: ^testing.T) {
	meta := FrameMeta{0, 1.0 / 60.0, 500, 700}

	keyboard_p := KeyboardInput{false, true, true}
	keyboard_c := KeyboardInput{false, false, true}

	last_frame := UserInput{meta, MouseInput{}, keyboard_p}
	current_frame := UserInput{meta, MouseInput{}, keyboard_c}

	input := FrameInput{current_frame, last_frame, false}

	testing.expect(t, input_was_right_arrow_pressed(input), "Right Arrow should have been pressed")
	testing.expect(t, !input_was_left_arrow_pressed(input), "Left Arrow should not be pressed")
	testing.expect(t, !input_was_space_pressed(input), "Space should not be pressed")
}

@(test)
test_is_mouse_button_ressed :: proc(t: ^testing.T) {
	meta := FrameMeta{0, 1.0 / 60.0, 500, 700}

	mouse_c := MouseInput{math.Vector2f32{}, true, false}
	mouse_p := MouseInput{math.Vector2f32{}, false, false}

	last_frame := UserInput{meta, mouse_p, KeyboardInput{}}
	current_frame := UserInput{meta, mouse_c, KeyboardInput{}}
	input := FrameInput{current_frame, last_frame, false}

	testing.expect(t, input_is_left_mouse_down(input), "Left mouse button is pressed")
	testing.expect(t, !input_is_right_mouse_down(input), "Right mouse button is not pressed")
}

@(test)
test_was_mouse_button_pressed :: proc(t: ^testing.T) {
	meta := FrameMeta{0, 1.0 / 60.0, 500, 700}
	mouse_c := MouseInput{math.Vector2f32{}, false, false}
	mouse_p := MouseInput{math.Vector2f32{}, true, false}

	last_frame := UserInput{meta, mouse_p, KeyboardInput{}}
	current_frame := UserInput{meta, mouse_c, KeyboardInput{}}
	input := FrameInput{current_frame, last_frame, false}

	testing.expect(t, input_was_left_mouse_pressed(input), "Left mouse button was pressed")
	testing.expect(t, !input_was_right_mouse_pressed(input), "Right mouse button was not pressed")
}

@(test)
test_mouse_position :: proc(t: ^testing.T) {
	meta := FrameMeta{0, 1.0 / 60.0, 500, 700}
	mouse_c := MouseInput{math.Vector2f32{10, 10}, false, false}
	mouse_p := MouseInput{math.Vector2f32{20, 20}, false, false}

	last_frame := UserInput{meta, mouse_p, KeyboardInput{}}
	current_frame := UserInput{meta, mouse_c, KeyboardInput{}}
	input := FrameInput{current_frame, last_frame, false}

	testing.expect(
		t,
		input_mouse_position(input) == math.Vector2f32{10, 10},
		"Mouse position is correct",
	)
	testing.expect(
		t,
		input_mouse_delta(input) == math.Vector2f32{-10, -10},
		"Mouse delta is correct",
	)
}
