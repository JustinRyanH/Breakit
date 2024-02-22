package input

import math "core:math/linalg"
import "core:testing"

KeyboardKey :: enum {
	// Alphanumeric keys
	APOSTROPH, // Key: '
	COMMA, // Key: ,
	MINUS, // Key: -
	PERIOD, // Key: .
	SLASH, // Key: /
	ZERO, // Key: 0
	ONE, // Key: 1
	TWO, // Key: 2
	THREE, // Key: 3
	FOUR, // Key: 4
	FIVE, // Key: 5
	SIX, // Key: 6
	SEVEN, // Key: 7
	EIGHT, // Key: 8
	NINE, // Key: 9
	SEMICOLON, // Key: ;
	EQUAL, // Key: =
	A, // Key: A | a
	B, // Key: B | b
	C, // Key: C | c
	D, // Key: D | d
	E, // Key: E | e
	F, // Key: F | f
	G, // Key: G | g
	H, // Key: H | h
	I, // Key: I | i
	J, // Key: J | j
	K, // Key: K | k
	L, // Key: L | l
	M, // Key: M | m
	N, // Key: N | n
	O, // Key: O | o
	P, // Key: P | p
	Q, // Key: Q | q
	R, // Key: R | r
	S, // Key: S | s
	T, // Key: T | t
	U, // Key: U | u
	V, // Key: V | v
	W, // Key: W | w
	X, // Key: X | x
	Y, // Key: Y | y
	Z, // Key: Z | z
	LEFT_BRACKET, // Key: [
	BACKSLASH, // Key: '\'
	RIGHT_BRACKET, // Key: ]
	GRAVE, // Key: `

	// Function keys
	SPACE, // Key: Space
	ESCAPE, // Key: Esc
	ENTER, // Key: Enter
	TAB, // Key: Tab
	BACKSPACE, // Key: Backspace
	INSERT, // Key: Ins
	DELETE, // Key: Del
	RIGHT, // Key: Cursor right
	LEFT, // Key: Cursor left
	DOWN, // Key: Cursor down
	UP, // Key: Cursor up
	PAGE_UP, // Key: Page up
	PAGE_DOWN, // Key: Page down
	HOME, // Key: Home
	END, // Key: End
	CAPS_LOCK, // Key: Caps lock
	SCROLL_LOCK, // Key: Scroll down
	NUM_LOCK, // Key: Num lock
	PRINT_SCREEN, // Key: Print screen
	PAUSE, // Key: Pause
	F1, // Key: F1
	F2, // Key: F2
	F3, // Key: F3
	F4, // Key: F4
	F5, // Key: F5
	F6, // Key: F6
	F7, // Key: F7
	F8, // Key: F8
	F9, // Key: F9
	F10, // Key: F10
	F11, // Key: F11
	F12, // Key: F12
	LEFT_SHIFT, // Key: Shift left
	LEFT_CONTROL, // Key: Control left
	LEFT_ALT, // Key: Alt left
	LEFT_SUPER, // Key: Super left
	RIGHT_SHIFT, // Key: Shift right
	RIGHT_CONTROL, // Key: Control right
	RIGHT_ALT, // Key: Alt right
	RIGHT_SUPER, // Key: Super right
	KB_MENU, // Key: KB menu

	// Keypad keys
	KP_0, // Key: Keypad 0
	KP_1, // Key: Keypad 1
	KP_2, // Key: Keypad 2
	KP_3, // Key: Keypad 3
	KP_4, // Key: Keypad 4
	KP_5, // Key: Keypad 5
	KP_6, // Key: Keypad 6
	KP_7, // Key: Keypad 7
	KP_8, // Key: Keypad 8
	KP_9, // Key: Keypad 9
	KP_DECIMAL, // Key: Keypad .
	KP_DIVIDE, // Key: Keypad /
	KP_MULTIPLY, // Key: Keypad *
	KP_SUBTRACT, // Key: Keypad -
	KP_ADD, // Key: Keypad +
	KP_ENTER, // Key: Keypad Enter
	KP_EQUAL, // Key: Keypad =

	// Android key buttons
	BACK, // Key: Android back button
	MENU, // Key: Android menu button
	VOLUME_UP, // Key: Android volume up button
	VOLUME_DOWN, // Key: Android volume down button
}

MouseButton :: enum {
	LEFT, // Mouse button left
	RIGHT, // Mouse button right
	MIDDLE, // Mouse button middle (pressed wheel)
	SIDE, // Mouse button side (advanced mouse device)
	EXTRA, // Mouse button extra (advanced mouse device)
	FORWARD, // Mouse button fordward (advanced mouse device)
	BACK, // Mouse button back (advanced mouse device)
}

FrameMeta :: struct {
	frame_id:      int,
	frame_delta:   f32,
	screen_width:  f32,
	screen_height: f32,
}

MouseInput :: struct {
	pos:     math.Vector2f32,
	buttons: bit_set[MouseButton],
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
	keyboard: bit_set[KeyboardKey],
}


// Information about current Frame,
// read by game and used for playback recording
FrameInput :: struct {
	current_frame: UserInput,
	last_frame:    UserInput,
}

BooleanInput :: union {
	KeyboardKey,
	MouseButton,
}


///////////////////////////////////////////
// User Input Functions
///////////////////////////////////////////


frame_next :: proc(previous_frame: FrameInput, user_input: UserInput) -> FrameInput {
	new_frame := FrameInput{}

	new_frame.last_frame = previous_frame.current_frame
	new_frame.current_frame = user_input

	new_frame.current_frame.meta.frame_id = previous_frame.current_frame.meta.frame_id + 1
	return new_frame
}


is_pressed :: proc(frame: FrameInput, key: BooleanInput) -> (res: bool) {
	switch i in key {
	case KeyboardKey:
		res = i in frame.current_frame.keyboard
	case MouseButton:
		res = i in frame.current_frame.mouse.buttons
	}
	return res
}

was_just_released :: proc(frame: FrameInput, key: BooleanInput) -> (res: bool) {
	switch i in key {
	case KeyboardKey:
		res = !(i in frame.current_frame.keyboard) && i in frame.last_frame.keyboard
	case MouseButton:
		res = !(i in frame.current_frame.mouse.buttons) && i in frame.last_frame.mouse.buttons
	}
	return res
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
mouse_position :: proc(frame_input: FrameInput) -> math.Vector2f32 {
	return frame_input.current_frame.mouse.pos
}

// Get the delta of the mouse position from the last frame
mouse_delta :: proc(frame_input: FrameInput) -> math.Vector2f32 {
	return frame_input.current_frame.mouse.pos - frame_input.last_frame.mouse.pos
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

	last_frame := UserInput{meta, MouseInput{}, {}}
	current_frame := UserInput{meta, MouseInput{}, {.RIGHT}}

	input := FrameInput{current_frame, last_frame}


	testing.expect(t, is_pressed(input, KeyboardKey.RIGHT), "Right Arrow should be down")
	testing.expect(t, !is_pressed(input, KeyboardKey.LEFT), "Left Arrow should not be down")
	testing.expect(t, !is_pressed(input, .SPACE), "Space should not be down")
}

@(test)
test_was_key_pressed :: proc(t: ^testing.T) {
	meta := FrameMeta{0, 1.0 / 60.0, 500, 700}

	keyboard_p := KeyboardInput{false, true, true}
	keyboard_c := KeyboardInput{false, false, true}

	last_frame := UserInput{meta, MouseInput{}, {.RIGHT, .SPACE}}
	current_frame := UserInput{meta, MouseInput{}, {.SPACE}}

	input := FrameInput{current_frame, last_frame}

	testing.expect(
		t,
		was_just_released(input, KeyboardKey.RIGHT),
		"Right Arrow should have been pressed",
	)
	testing.expect(
		t,
		!was_just_released(input, KeyboardKey.LEFT),
		"Left Arrow should not be pressed",
	)
	testing.expect(t, !was_just_released(input, .SPACE), "Space should not be pressed")
}

@(test)
test_is_mouse_button_ressed :: proc(t: ^testing.T) {
	meta := FrameMeta{0, 1.0 / 60.0, 500, 700}

	mouse_c := MouseInput{math.Vector2f32{}, {.LEFT}}
	mouse_p := MouseInput{math.Vector2f32{}, {}}

	last_frame := UserInput{meta, mouse_p, {}}
	current_frame := UserInput{meta, mouse_c, {}}
	input := FrameInput{current_frame, last_frame}

	testing.expect(t, is_pressed(input, MouseButton.LEFT), "Left mouse button is pressed")
	testing.expect(t, !is_pressed(input, MouseButton.RIGHT), "Right mouse button is not pressed")
}

@(test)
test_was_mouse_button_pressed :: proc(t: ^testing.T) {
	meta := FrameMeta{0, 1.0 / 60.0, 500, 700}
	mouse_c := MouseInput{math.Vector2f32{}, {}}
	mouse_p := MouseInput{math.Vector2f32{}, {.LEFT}}

	last_frame := UserInput{meta, mouse_p, {}}
	current_frame := UserInput{meta, mouse_c, {}}
	input := FrameInput{current_frame, last_frame}

	testing.expect(t, was_just_released(input, MouseButton.LEFT), "Left mouse button was pressed")
	testing.expect(
		t,
		!was_just_released(input, MouseButton.RIGHT),
		"Right mouse button was not pressed",
	)
}

@(test)
test_mouse_position :: proc(t: ^testing.T) {
	meta := FrameMeta{0, 1.0 / 60.0, 500, 700}
	mouse_c := MouseInput{math.Vector2f32{10, 10}, {}}
	mouse_p := MouseInput{math.Vector2f32{20, 20}, {}}

	last_frame := UserInput{meta, mouse_p, {}}
	current_frame := UserInput{meta, mouse_c, {}}
	input := FrameInput{current_frame, last_frame}

	testing.expect(
		t,
		mouse_position(input) == math.Vector2f32{10, 10},
		"Mouse position is correct",
	)
	testing.expect(t, mouse_delta(input) == math.Vector2f32{-10, -10}, "Mouse delta is correct")
}
