package input

import "core:fmt"
import "core:math"
import "core:os"
import "core:strings"
import "core:time"

import rl "vendor:raylib"

import game "../game"
import mu "../microui"
import rl_platform "../raylib_platform"


VcrRecording :: struct {
	current_frame: game.FrameInput,
}

VcrPlayback :: struct {
	current_index: int,
	active:        bool,
}

VcrLoop :: struct {
	current_index: int,
	start_index:   int,
	end_index:     int,
	active:        bool,
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
	loop_min:                mu.Real,
	loop_max:                mu.Real,
}

InputFileSystem :: struct {
	current_file: string,
	io:           GameInputIO,
}

// We are going to free the previous file,
// so let's start with a copy of empty string instead of a static
input_file_setup :: proc(ifs: ^InputFileSystem) {
	ifs.current_file = strings.clone("")
}

input_file_new_file :: proc(ifs: ^InputFileSystem) {
	old_str := ifs.current_file
	now := time.to_unix_seconds(time.now())
	log_name := fmt.tprintf("logs/file-%d.ilog", now)
	ifs.current_file = strings.clone(log_name)
	delete(old_str)
}

input_file_set_new_file :: proc(ifs: ^InputFileSystem, new_file: string) {
	delete(ifs.current_file)
	ifs.current_file = strings.clone(new_file)
}

input_file_begin_write :: proc(
	ifs: ^InputFileSystem,
) -> (
	writer: GameInputWriter,
	err: GameInputError,
) {
	game_input_close(&ifs.io)

	new_writer := game_input_writer_create(ifs.current_file)
	err = game_input_writer_open(&new_writer)
	ifs.io = new_writer
	return new_writer, err
}

input_file_begin_read :: proc(
	ifs: ^InputFileSystem,
) -> (
	reader: GameInputReader,
	err: GameInputError,
) {
	game_input_close(&ifs.io)

	new_reader := game_input_reader_create(ifs.current_file)
	err = game_input_reader_open(&new_reader)
	ifs.io = new_reader
	return
}

input_file_write_frame :: proc(
	ifs: ^InputFileSystem,
	new_frame: game.FrameInput,
) -> GameInputError {
	writer, ok := ifs.io.(GameInputWriter)
	if ok {
		return game_input_writer_insert_frame(&writer, new_frame)
	}
	return .NotInReadMode
}

input_file_read_input :: proc(
	ifs: ^InputFileSystem,
) -> (
	input: game.UserInput,
	err: GameInputError,
) {
	reader, ok := ifs.io.(GameInputReader)
	if ok {
		return game_input_reader_read_input(&reader)
	}
	return game.UserInput{}, .NotInWriteMode
}


FrameHistory :: [dynamic]game.UserInput

InputDebuggerState :: struct {
	ifs:      InputFileSystem,
	playback: VcrState,
}

input_debugger_setup :: proc(state: ^InputDebuggerState) {
	state.playback.frame_history = make([dynamic]game.UserInput, 0, 1024 * 128)
	state.playback.state = VcrRecording{}
}

input_debugger_teardown :: proc(state: ^InputDebuggerState) {
	delete(state.playback.frame_history)
}

input_debugger_load_file :: proc(
	state: ^InputDebuggerState,
	file: string,
) -> (
	err: GameInputError,
) {
	input_file_set_new_file(&state.ifs, file)
	clear_frame_history(state)
	clear(&state.playback.frame_history)
	state.playback.has_loaded_all_playback = false

	switch v in state.playback.state {
	case VcrRecording:
		return .NotInReadMode
	case VcrPlayback:
		_, err = input_file_begin_read(&state.ifs)
		if err != nil {
			return
		}
		state.playback.state = VcrPlayback{0, v.active}
	case VcrLoop:
		_, err = input_file_begin_read(&state.ifs)
		if err != nil {
			return
		}
		state.playback.state = VcrLoop{0, 0, 0, v.active}
	}
	return
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

input_debugger_gui :: proc(state: ^InputDebuggerState, ctx: ^mu.Context) {

	mu.begin(ctx)
	defer mu.end(ctx)

	window_width: i32 = 400
	window_height: i32 = 450

	if !input_debugger_query_if_recording(state) {
		if mu.window(
			   ctx,
			   "Input Recording",
			   {800 - window_width, 0, window_width, window_height},
			   {.NO_CLOSE},
		   ) {

			gui_file_explorer(state, ctx)
			gui_playback_controls(state, ctx)
			gui_frame_list(state, ctx)
		}
	}
}

gui_file_explorer :: proc(state: ^InputDebuggerState, ctx: ^mu.Context) {
	mu.layout_row(ctx, {-1})
	mu.label(ctx, fmt.tprintf("Loaded File: %s", state.ifs.current_file))

	header_res := mu.header(ctx, "Input Files", {.CLOSED})
	if .ACTIVE not_in header_res {
		log_dir, err := os.open("logs")

		if err != os.ERROR_NONE {
			fmt.printf("Errno: %v", err)
			return
		}
		defer os.close(log_dir)

		files, dir_err := os.read_dir(log_dir, 50, context.temp_allocator)

		if dir_err != os.ERROR_NONE {
			fmt.printf("Errno: %v", err)
			return
		}

		for file in files {
			mu.layout_row(ctx, {-1})
			button_ref := mu.button(ctx, fmt.tprintf("Load %s", file.name))
			if .SUBMIT in button_ref {
				new_file := fmt.tprintf("logs/%s", file.name)
				err := input_debugger_load_file(state, new_file)
				if err != nil {
					fmt.printf("Err: %v", err)
					return
				}
			}
		}

		return
	}
}


gui_playback_controls :: proc(state: ^InputDebuggerState, ctx: ^mu.Context) {
	res := mu.header(ctx, "Playback Controls", {.EXPANDED})
	if .ACTIVE not_in res {
		return
	}

	#partial switch v in &state.playback.state {
	case VcrPlayback:
		mu.layout_row(ctx, {50, 50, 50, 50})
		if mu.button(ctx, "LOOP", .NONE) == {.SUBMIT} {
			fh_len := frame_history_len(state)
			state.playback.state = VcrLoop{0, 0, fh_len - 1, v.active}
			state.playback.loop_min = cast(f32)0
			state.playback.loop_max = cast(f32)fh_len - 1
		}

		txt := "PAUSE" if v.active else "RESUME"
		if mu.button(ctx, txt, .NONE) == {.SUBMIT} {
			v.active = !v.active
		}

		if !v.active {
			if mu.button(ctx, "STEP >", .NONE) == {.SUBMIT} {
				step_playback(state, &v)
			}
		}

		if mu.button(ctx, "RESTART", .NONE) == {.SUBMIT} {
			v.current_index = 0
		}

	case VcrLoop:
		mu.layout_row(ctx, {50, 75, 75, 50, 50, 50})

		if mu.button(ctx, "Back", .NONE) == {.SUBMIT} {
			state.playback.state = VcrPlayback{v.current_index, v.active}
		}

		fh_len := frame_history_len(state)

		slider_res := mu.slider(
			ctx,
			&state.playback.loop_min,
			0,
			cast(mu.Real)v.end_index - 1 if v.end_index != 0 else 0,
			1,
			"Start Frame: %.0f",
		)
		if .CHANGE in slider_res {
			v.start_index = cast(int)state.playback.loop_min
		}
		slider_res = mu.slider(
			ctx,
			&state.playback.loop_max,
			cast(mu.Real)v.start_index + 1 if fh_len != 0 else 0,
			cast(mu.Real)fh_len,
			1,
			"End Frame: %.0f",
		)
		if .CHANGE in slider_res {
			v.end_index = cast(int)state.playback.loop_max
		}

		txt := "PAUSE" if v.active else "RESUME"
		if mu.button(ctx, txt, .NONE) == {.SUBMIT} {
			v.active = !v.active
		}

		if !v.active {
			if mu.button(ctx, "STEP >", .NONE) == {.SUBMIT} {
				step_loop(state, &v)
			}
		}

		if mu.button(ctx, "RESTART", .NONE) == {.SUBMIT} {
			v.current_index = v.start_index
		}
	}
}

gui_frame_list :: proc(state: ^InputDebuggerState, ctx: ^mu.Context) {
	res := mu.header(ctx, "Frame List", {.CLOSED})
	if .ACTIVE not_in res {
		return
	}

	frame_history := input_get_frame_history(state)
	for frame, frame_index in frame_history {
		font := ctx.style.font
		label := fmt.tprintf("%v", frame)

		text_width := ctx.text_width(font, label)
		mu.layout_row(ctx, {32, text_width, -1})
		res := mu.button(ctx, fmt.tprintf("%d", frame_index), .NONE)

		mu.label(ctx, label)
		if .SUBMIT in res {
			#partial switch v in &state.playback.state {
			case VcrPlayback:
				v.current_index = frame_index
			}
		}
	}
}


read_write_frame :: proc(state: ^InputDebuggerState) -> GameInputError {
	switch s in &state.playback.state {
	case VcrRecording:
		new_frame := rl_platform.update_frame(s.current_frame)
		s.current_frame = new_frame
		err := input_file_write_frame(&state.ifs, new_frame)
		if err != nil {
			return nil
		}
		rl.DrawText("Recording", 10, 30, 20, rl.RED)
		return nil
	case VcrPlayback:
		if state.playback.has_loaded_all_playback {
			rl.DrawText("Playback Loaded", 10, 30, 20, rl.RED)
		} else {
			rl.DrawText("Playback Loading", 10, 30, 20, rl.RED)
		}
		return playback_input(state)
	case VcrLoop:
		rl.DrawText(
			fmt.ctprintf(
				"Looping from %d to %d: frame %d",
				s.start_index,
				s.end_index,
				s.current_index,
			),
			10,
			30,
			20,
			rl.RED,
		)
		return playback_input(state)
	}
	return nil
}

input_debugger_draw :: proc(state: ^InputDebuggerState) {
	switch s in state.playback.state {
	case VcrRecording:
		rl.DrawText("Recording", 10, 30, 20, rl.RED)
	case VcrPlayback:
		if state.playback.has_loaded_all_playback {
			rl.DrawText("Playback Loaded", 10, 30, 20, rl.RED)
		} else {
			rl.DrawText("Playback Loading", 10, 30, 20, rl.RED)
		}
	case VcrLoop:
		rl.DrawText(
			fmt.ctprintf(
				"Looping from %d to %d: frame %d",
				s.start_index,
				s.end_index,
				s.current_index,
			),
			10,
			30,
			20,
			rl.RED,
		)
	}

}

input_debugger_toggle_playback :: proc(state: ^InputDebuggerState) -> GameInputError {
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
		for i := 0; i < 30; i += 1 {
			new_frame, err := input_file_read_input(&state.ifs)
			if err == .NoMoreFrames {
				state.playback.has_loaded_all_playback = true
				break
			} else if err != nil {
				return nil
			} else {
				append(&state.playback.frame_history, new_frame)
			}
		}
		loop, ok := &state.playback.state.(VcrLoop)
		if ok {
			loop.end_index = len(state.playback.frame_history) - 1
			state.playback.loop_max = cast(mu.Real)loop.end_index
		}
	}
	#partial switch v in &state.playback.state {
	case VcrPlayback:
		if !v.active {
			return nil
		}
		step_playback(state, &v)
	case VcrLoop:
		if !v.active {
			return nil
		}
		step_loop(state, &v)
	}

	return nil
}

step_playback :: proc(state: ^InputDebuggerState, v: ^VcrPlayback) {
	len_of_history := frame_history_len(state)
	if len_of_history == 0 {
		return
	}
	v.current_index += 1
	if v.current_index >= len_of_history {
		v.current_index = 0
		v.active = false
	}
}
step_loop :: proc(state: ^InputDebuggerState, v: ^VcrLoop) {
	len_of_history := frame_history_len(state)
	if len_of_history == 0 {
		return
	}
	v.current_index += 1
	if v.current_index > v.end_index {
		v.current_index = v.start_index
	}
}

@(private)
toggle_recording :: proc(state: ^InputDebuggerState) -> (err: GameInputError) {
	input_file_new_file(&state.ifs)
	_, err = input_file_begin_write(&state.ifs)

	new_frame := rl_platform.update_frame(game.FrameInput{})
	clear_frame_history(state)
	state.playback.state = VcrRecording{new_frame}
	return
}

@(private)
clear_frame_history :: proc(state: ^InputDebuggerState) {
	clear(&state.playback.frame_history)
	state.playback.has_loaded_all_playback = false
}

@(private)
toggle_playback :: proc(state: ^InputDebuggerState) -> (err: GameInputError) {
	_, err = input_file_begin_read(&state.ifs)
	new_frame := game.UserInput{}

	state.playback.state = VcrPlayback{0, false}
	return
}


@(private = "file")
frame_at_index :: proc(state: ^InputDebuggerState, idx: int) -> game.FrameInput {
	if frame_history_len(state) == 0 {
		return game.FrameInput{}
	}

	previous_frame := state.playback.frame_history[idx - 1] if idx > 0 else game.UserInput{}
	current_frame := state.playback.frame_history[idx]
	return game.FrameInput{previous_frame, current_frame, false}
}


@(private = "file")
frame_history_len :: proc(state: ^InputDebuggerState) -> int {
	return len(state.playback.frame_history)
}
