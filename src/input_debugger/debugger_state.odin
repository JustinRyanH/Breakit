package input

import "core:fmt"
import "core:math"

import rl "vendor:raylib"

import game "../game"
import mu "../microui"
import rl_platform "../raylib_platform"

VcrRecording :: struct {
	current_frame: game.FrameInput,
}

VcrPlayback :: struct {
	current_index: int,
	paused:        bool,
}

VcrLoop :: struct {
	current_index: int,
	start_index:   int,
	end_index:     int,
	paused:        bool,
}

PlaybackState :: union {
	VcrRecording,
	VcrPlayback,
	VcrLoop,
}


VcrState :: struct {
	frame_history:           FrameHistory,
	state:                   PlaybackState,
	has_loaded_all_playback: bool,
}

FrameHistory :: [dynamic]game.UserInput

InputDebuggerState :: struct {
	writer:   GameInputWriter,
	reader:   GameInputReader,
	frame:    game.FrameInput,
	playback: VcrState,
}

input_debugger_setup :: proc(state: ^InputDebuggerState) {
	state.playback.frame_history = make([dynamic]game.UserInput, 0, 1024 * 128)
	state.playback.state = VcrRecording{}
}

input_debugger_teardown :: proc(state: ^InputDebuggerState) {
	delete(state.playback.frame_history)
}

input_debugger_query_if_recording :: proc(state: ^InputDebuggerState) -> bool {
	_, ok := state.playback.state.(VcrRecording)
	return ok
}

input_debugger_query_current_frame :: proc(
	state: ^InputDebuggerState,
) -> (
	frame_input: game.FrameInput,
) {
	switch v in state.playback.state {
	case VcrRecording:
		frame_input = v.current_frame
	case VcrPlayback:
		return frame_at_index(state, v.current_index)
	case VcrLoop:
		return frame_at_index(state, v.current_index)
	}
	return
}


input_get_frame_history :: proc(state: ^InputDebuggerState) -> FrameHistory {
	return state.playback.frame_history
}

input_debugger_gui :: proc(db_state: ^InputDebuggerState, ctx: ^mu.Context) {

	mu.begin(ctx)
	defer mu.end(ctx)

	window_width: i32 = 400
	window_height: i32 = 450

	if !input_debugger_query_if_recording(db_state) {
		if mu.window(
			   ctx,
			   "Input Recording",
			   {800 - window_width, 0, window_width, window_height},
			   {.NO_CLOSE},
		   ) {
			mu.layout_row(ctx, {50, 50, 75, 75, 50})

			#partial switch v in &db_state.playback.state {
			case VcrPlayback:
				// FIX: This is backwards
				txt := "PAUSED" if v.paused else "RESUME"
				if mu.button(ctx, txt, .NONE) == {.SUBMIT} {
					v.paused = !v.paused
				}
				if mu.button(ctx, "LOOP", .NONE) == {.SUBMIT} {
					db_state.playback.state = VcrLoop {
						0,
						0,
						len(db_state.playback.frame_history) - 1,
						false,
					}
				}

			case VcrLoop:
				@(static)
				slider_start: mu.Real

				@(static)
				slider_end: mu.Real

				txt := "PAUSED" if v.paused else "RESUME"
				if mu.button(ctx, txt, .NONE) == {.SUBMIT} {
					v.paused = !v.paused
				}

				mu.slider(ctx, &slider_start, 0, 50, 1, "Start Frame: %.0f")
				mu.slider(ctx, &slider_end, 50, 100, 1, "End Frame: %.0f")

			}


			if mu.button(ctx, "RESTART", .NONE) == {.SUBMIT} {
				db_state.playback.state = VcrPlayback{0, false}
			}

			// FIX:  This is no longer displaying
			if mu.header(ctx, "Frame List", {.CLOSED}) == {.ACTIVE} {
				frame_history := input_get_frame_history(db_state)
				for frame, frame_index in frame_history {
					font := ctx.style.font
					label := fmt.tprintf("%v", frame)

					text_width := ctx.text_width(font, label)
					mu.layout_row(ctx, {32, text_width, -1})
					res := mu.button(ctx, fmt.tprintf("%d", frame_index), .NONE)
					if .SUBMIT in res {
						#partial switch v in &db_state.playback.state {
						case VcrPlayback:
							v.current_index = frame_index
						}

						mu.label(ctx, label)
					}
				}
			}
		}

	}
}

read_write_frame :: proc(state: ^InputDebuggerState) -> GameInputError {
	switch s in &state.playback.state {
	case VcrRecording:
		state.frame = rl_platform.update_frame(state.frame)
		s.current_frame = state.frame
		err := game_input_writer_insert_frame(&state.writer, state.frame)
		if err != nil {
			return err
		}
		rl.DrawText("Recording", 10, 30, 20, rl.RED)
		return nil
	case VcrPlayback:
		if state.playback.has_loaded_all_playback {
			rl.DrawText("Playback Finished", 10, 30, 20, rl.RED)
		} else {
			rl.DrawText("Playback", 10, 30, 20, rl.RED)
		}
		return playback_input(state)
	case VcrLoop:
		rl.DrawText(
			fmt.ctprintf("Looping from %d to %d", s.start_index, s.end_index),
			10,
			30,
			20,
			rl.RED,
		)
	}
	return nil
}

input_debugger_toggle_playback :: proc(state: ^InputDebuggerState) -> (err: GameInputError) {
	switch s in state.playback.state {
	case VcrRecording:
		return toggle_playback(state)
	case VcrPlayback:
		return toggle_recording(state)
	case VcrLoop:
		return toggle_recording(state)
	}
	return nil
}


//////////////////////
// Private Procs
//////////////////////

@(private)
playback_input :: proc(state: ^InputDebuggerState) -> GameInputError {
	if !state.playback.has_loaded_all_playback {
		new_frame, err := game_input_reader_read_input(&state.reader)
		if err == .NoMoreFrames {
			state.playback.has_loaded_all_playback = true
		} else if err != nil {
			return nil
		} else {
			append(&state.playback.frame_history, new_frame)
		}
	}
	v, ok := &state.playback.state.(VcrPlayback)
	if ok {
		len_of_history := len(state.playback.frame_history)
		if len_of_history == 0 {
			return nil
		}
		v.current_index = math.clamp(v.current_index + 1, 0, len_of_history - 1)
	}

	state.frame = input_debugger_query_current_frame(state)
	return nil
}

@(private)
toggle_recording :: proc(state: ^InputDebuggerState) -> (err: GameInputError) {
	game_input_reader_close(&state.reader)
	err = game_input_writer_open(&state.writer)
	if err != nil {
		return
	}
	state.frame = rl_platform.update_frame(game.FrameInput{})
	game_input_writer_insert_frame(&state.writer, state.frame)
	rl.SetTargetFPS(30)
	state.playback.state = VcrRecording{}
	clear(&state.playback.frame_history)
	state.playback.has_loaded_all_playback = false
	return
}

@(private)
toggle_playback :: proc(state: ^InputDebuggerState) -> (err: GameInputError) {
	new_frame := game.UserInput{}

	game_input_writer_close(&state.writer)
	err = game_input_reader_open(&state.reader)
	if err != nil {
		return err
	}

	state.frame = game.FrameInput{}
	new_frame, err = game_input_reader_read_input(&state.reader)
	if err != nil {
		return err
	}

	rl.SetTargetFPS(120)
	state.playback.state = VcrPlayback{0, false}

	return
}


@(private = "file")
frame_at_index :: proc(state: ^InputDebuggerState, idx: int) -> game.FrameInput {
	if len(state.playback.frame_history) == 0 {
		return game.FrameInput{}
	}

	previous_frame := state.playback.frame_history[idx - 1] if idx > 0 else game.UserInput{}
	current_frame := state.playback.frame_history[idx]
	return game.FrameInput{previous_frame, current_frame, false}
}
