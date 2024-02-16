package main


import "core:c/libc"
import "core:dynlib"
import "core:fmt"
import "core:os"
import "core:path/filepath"

import rl "vendor:raylib"

import "../game"
import "../game/input"
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
	idb := new(input.InputDebuggerState)
	defer free(idb)

	input.debugger_setup(idb)
	defer input.debugger_teardown(idb)

	input.debugger_start_write(idb)

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
				input.debugger_pause(idb)
			case game.ResumeCmd:
				input.debugger_unpause(idb)
			case game.ReplayCmd:
				game_api.shutdown()
				game_api.hot_reloaded(frame_zero)

				frame_zero = game_api.copy_memory()
				err := input.debugger_toggle_playback(idb)
				if err != nil {
					fmt.printf("Err: %v", err)
					return
				}
				idb.general_debug = false
			}
			ctx.frame_cmd = nil
		}

		if (rl.IsKeyReleased(.F5)) {
			game_api.shutdown()
			game_api.init()
			game_api.setup(ctx)
		}

		if (rl.IsKeyReleased(.F1)) {
			idb.general_debug = !idb.general_debug
			if (idb.general_debug) {
				ctx.frame_cmd = game.PauseCmd{}
			} else {
				ctx.frame_cmd = game.ResumeCmd{}
			}
		}

		if (rl.IsKeyReleased(.F2)) {idb.draw_debug = !idb.draw_debug}

		rl_platform.load_input(&ctx.mui)
		user_input := rl_platform.get_current_user_input()
		err := input.debugger_load_next_frame(idb, user_input)

		old_frame := ctx.frame
		ctx.frame = input.debugger_query_current_frame(idb)

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
