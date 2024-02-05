package main


import "core:c/libc"
import "core:dynlib"
import "core:fmt"
import "core:os"
import "core:path/filepath"

import rl "vendor:raylib"

import "../game"
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

	ctx := platform_new_context()
	defer deinit_game_context(ctx)

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

		ctx.frame = platform_update_frame(ctx.frame)
		should_exit := game_api.update(ctx)
		if (should_exit) {
			break
		}

		game_api.draw(&ctx.draw_cmds)

		dll_time, dll_time_err := os.last_write_time_by_name(game_api_file_path(game_api))
		reload := dll_time_err == os.ERROR_NONE && game_api.dll_time != dll_time

		if reload {
			game_api = game_api_hot_load(game_api)
		}
	}

	game_api.shutdown()
	game_api_unload(game_api)
}
