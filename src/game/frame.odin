package game

import "core:testing"

FrameMeta :: struct {
	frame_id:      int,
	frame_delta:   f32,
	screen_width:  f32,
	screen_height: f32,
}

// Tracked User State Input
UserInput :: struct {
	meta:       FrameMeta,

	// Keyboard Input
	left_down:  bool,
	right_down: bool,
	space_down: bool,
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

// Is the Right Arrow down this frame
is_right_arrow_down :: proc(input: FrameInput) -> bool {
	return input.current_frame.right_down
}

// Was the Right Arrow pressed the framae before
was_right_arrow_pressed :: proc(input: FrameInput) -> bool {
	return input.current_frame.right_down && !input.last_frame.right_down
}


// Is the Left Arrow down this frame
is_left_arrow_down :: proc(input: FrameInput) -> bool {
	return input.current_frame.left_down
}

// Was the Left Arrow pressed the frame before
was_left_arrow_pressed :: proc(input: FrameInput) -> bool {
	return input.current_frame.left_down && !input.last_frame.left_down
}

// Is the Space key down this frame
is_space_down :: proc(input: FrameInput) -> bool {
	return input.current_frame.space_down
}

// Was the Space key pressed the frame before
was_space_pressed :: proc(input: FrameInput) -> bool {
	return input.current_frame.space_down && !input.last_frame.space_down
}

///////////////////////////////////////////
// Testing
///////////////////////////////////////////

@(test)
test_is_key_down :: proc(t: ^testing.T) {
	meta := FrameMeta{0, 1.0 / 60.0, 500, 700}
	current_frame := UserInput{meta, false, true, false}
	last_frame := UserInput{meta, false, false, false}

	input := FrameInput{current_frame, last_frame}


	testing.expect(t, is_right_arrow_down(input), "Right Arrow should be down")
	testing.expect(t, !is_left_arrow_down(input), "Left Arrow should not be down")
	testing.expect(t, !is_space_down(input), "Space should not be down")
}

@(test)
test_was_key_pressed :: proc(t: ^testing.T) {
	meta := FrameMeta{0, 1.0 / 60.0, 500, 700}
	current_frame := UserInput{meta, false, true, false}
	last_frame := UserInput{meta, false, false, true}
	input := FrameInput{current_frame, last_frame}

	testing.expect(t, was_right_arrow_pressed(input), "Right Arrow should be pressed")
	testing.expect(t, !was_left_arrow_pressed(input), "Left Arrow should not be pressed")
	testing.expect(t, !was_space_pressed(input), "Space should not be pressed")
}
