package main

import rl "vendor:raylib"

import "game"


build_raylib_platform :: proc() -> (cmd: game.PlatformCommands) {
	cmd.should_close_game = cast(proc() -> bool)(rl.WindowShouldClose)
	cmd.begin_drawing = cast(proc())(rl.BeginDrawing)
	cmd.end_drawing = cast(proc())(rl.EndDrawing)

	return cmd
}
