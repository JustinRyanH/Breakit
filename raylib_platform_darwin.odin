package main


import "core:c/libc"
import "core:dynlib"
import "core:fmt"
import "core:os"
import "core:path/filepath"

import rl "vendor:raylib"

import "game"


main :: proc() {
	game_api, game_api_ok := game_api_load(0, "game", "./bin")

	if !game_api_ok {
		fmt.println("Failed to load Game API")
		return
	}
	fmt.println("Loaded Game API")

	game_api.init()

	rl.InitWindow(800, 600, "Breakit")
	defer rl.CloseWindow()

	rl.SetTargetFPS(30.0)

	for {
		if (game_api.update() == false) {
			break
		}
		if (rl.WindowShouldClose()) {
			break
		}

		dll_time, dll_time_err := os.last_write_time_by_name(game_api_file_path(game_api))
		reload := dll_time_err == os.ERROR_NONE && game_api.dll_time != dll_time

		if reload {
			game_api = game_api_hot_load(game_api)
		}

		{
			rl.BeginDrawing()
			defer rl.EndDrawing()

			rl.ClearBackground(rl.RAYWHITE)
			rl.DrawText("Breakit", 200, 200, 20, rl.DARKGRAY)
		}
		free_all(context.temp_allocator)
	}

	game_api.shutdown()
	game_api_unload(game_api)
}
