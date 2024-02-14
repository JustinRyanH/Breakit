package input


import "core:fmt"
import "core:math"
import "core:os"

import mu "../microui"

input_debugger_mui :: proc(ctx: ^mu.Context, state: ^InputDebuggerState) {
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

			input_debugger_files(ctx, state)
			input_debugger_playback(ctx, state)
		}
	}
}


input_debugger_files :: proc(ctx: ^mu.Context, state: ^InputDebuggerState) {
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

input_debugger_playback :: proc(ctx: ^mu.Context, state: ^InputDebuggerState) {
	res := mu.header(ctx, "Playback Controls", {.EXPANDED})
	if .ACTIVE not_in res {
		return
	}
	fh_len := len(state.playback.frame_history)

	#partial switch v in &state.playback.state {
	case VcrPlayback:
		mu.layout_row(ctx, {50, 50, 50, 50})
		if mu.button(ctx, "LOOP", .NONE) == {.SUBMIT} {

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
