package main


import "core:c/libc"
import "core:dynlib"
import "core:fmt"
import "core:os"
import "core:path/filepath"

import rl "vendor:raylib"

import "../game"
import rl_platform "../raylib_platform"
import ta "../tracking_alloc"


main :: proc() {
	default_allocator := context.allocator
	tracking_allocator: ta.Tracking_Allocator
	ta.tracking_allocator_init(&tracking_allocator, default_allocator)
	context.allocator = ta.allocator_from_tracking_allocator(&tracking_allocator)
	defer ta.tracking_allocator_destroy(&tracking_allocator)


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

	for {
		defer free_all(context.temp_allocator)

		if (rl.IsKeyReleased(.F5)) {
			game_api.shutdown()
			game_api.init()
			game_api.setup(ctx)
		}

		rl_platform.load_input(&ctx.mui)
		input := rl_platform.get_current_user_input()

		ctx.frame = game.frame_next(ctx.frame, input)
		if (rl.IsKeyPressed(.F1)) {game.frame_toggle_debug(&ctx.frame)}

		should_exit := game_api.update(ctx)
		if (should_exit) {
			break
		}

		game_api.draw(&ctx.draw_cmds)

		rl_platform.render_mui(&ctx.mui)

		dll_time, dll_time_err := os.last_write_time_by_name(game_api_file_path(game_api))
		reload := dll_time_err == os.ERROR_NONE && game_api.dll_time != dll_time

		if reload {
			game_api = game_api_hot_load(game_api)
		}
	}

	game_api.shutdown()
	game_api_unload(game_api)
}
