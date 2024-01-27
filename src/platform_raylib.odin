package main

import rl "vendor:raylib"

import "game"

build_raylib_platform :: proc() -> (cmd: game.PlatformCommands) {
	cmd.should_close_game = cast(proc() -> bool)(rl.WindowShouldClose)
	cmd.begin_drawing = cast(proc())(rl.BeginDrawing)
	cmd.end_drawing = cast(proc())(rl.EndDrawing)
	cmd.clear = raylib_clear_background

	return cmd
}

raylib_clear_background :: proc(color: game.Color) {
	rl.ClearBackground(rl.Color(color))
}
