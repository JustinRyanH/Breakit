package main


import "core:c/libc"
import "core:dynlib"
import "core:fmt"
import "core:os"
import "core:path/filepath"

import rl "vendor:raylib"

import "../game"
import  "../game/input"
import rl_platform "../raylib_platform"
import ta "../tracking_alloc"

frame_zero: rawptr = nil


main :: proc() {
	default_allocator := context.allocator
	tracking_allocator: ta.Tracking_Allocator
	ta.tracking_allocator_init(&tracking_allocator, default_allocator)
	context.allocator = ta.allocator_from_tracking_allocator(&tracking_allocator)
	defer ta.tracking_allocator_destroy(&tracking_allocator)

	// TODO: let's just throw this on global
	idb_state := new(input.InputDebuggerState)
	defer free(idb_state)

	input.debugger_setup(idb_state)
	defer input.debugger_teardown(idb_state)

	input.debugger_start_write(idb_state)

	rl.InitWindow(800, 600, "Breakit")
	rl.SetTargetFPS(60.0)
	defer rl.CloseWindow()

	ctx := rl_platform.new_context()
	defer rl_platform.deinit_game_context(ctx)
	rl_platform.setup_raylib_mui(&ctx.mui)
	defer rl_platform.destroy_raylib_mui()

	game_api, game_api_ok := game_api_load(0, "game", "./bin")

	if !game_api_ok {
		fmt.println("Failed to load Game API")
		return
	}

	game_api.init()
	game_api.setup(ctx)

	frame_zero = game_api.copy_memory()


	for {
		defer free_all(context.temp_allocator)
		if (ctx.frame_cmd != nil) {
			switch cmd in ctx.frame_cmd {
			case game.PauseCmd:
				input.debugger_pause(idb_state)
			case game.ResumeCmd:
				input.debugger_unpause(idb_state)
			case game.ReplayCmd:
				game_api.shutdown()
				game_api.hot_reloaded(frame_zero)

				frame_zero = game_api.copy_memory()
			}
			ctx.frame_cmd = nil
		}

		if (rl.IsKeyReleased(.F5)) {
			game_api.shutdown()
			game_api.init()
			game_api.setup(ctx)
		}

		if (rl.IsKeyReleased(.F1)) {
			idb_state.general_debug = !idb_state.general_debug
			if (idb_state.general_debug) {
				ctx.frame_cmd = game.PauseCmd{}
			} else {
				ctx.frame_cmd = game.ResumeCmd{}
			}
		}

		if (rl.IsKeyReleased(.F2)) {idb_state.draw_debug = !idb_state.draw_debug}

		rl_platform.load_input(&ctx.mui)
		user_input := rl_platform.get_current_user_input()
		err := input.debugger_load_next_frame(idb_state, user_input)

		old_frame := ctx.frame
		ctx.frame = input.debugger_query_current_frame(idb_state)

		should_exit := game_api.update(ctx)
		if (should_exit) {
			break
		}

		game_api.draw(&ctx.draw_cmds)

		rl_platform.render_mui(&ctx.mui)

		dll_time, dll_time_err := os.last_write_time_by_name(game_api_file_path(game_api))
		reload := dll_time_err == os.ERROR_NONE && game_api.dll_time != dll_time

		rl.DrawFPS(10, 10)

		if reload {
			game_api = game_api_hot_load(game_api)
		}
	}
	game_api.delete_copy(frame_zero)

	game_api.shutdown()
	game_api_unload(game_api)
}
