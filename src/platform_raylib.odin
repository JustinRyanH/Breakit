package main

import "core:fmt"

import rl "vendor:raylib"

import "game"

build_raylib_platform :: proc() -> ^game.PlatformCommands {
	cmd := new(game.PlatformCommands)
	cmd.should_close_game = cast(proc() -> bool)(rl.WindowShouldClose)
	return cmd
}

cleanup_raylib_platform :: proc(cmd: ^game.PlatformCommands) {
	free(cmd)
}

build_raylib_platform_draw :: proc() -> ^game.PlatformDrawCommands {
	cmd := new(game.PlatformDrawCommands)
	cmd.begin_drawing = cast(proc())(rl.BeginDrawing)
	cmd.end_drawing = cast(proc())(rl.EndDrawing)
	cmd.clear = raylib_clear_background
	cmd.draw_text = raylib_draw_text

	return cmd
}

cleanup_raylib_platform_draw :: proc(cmd: ^game.PlatformDrawCommands) {
	free(cmd)
}

raylib_clear_background :: proc(color: game.Color) {
	rl.ClearBackground(rl.Color(color))
}

raylib_draw_text :: proc(msg: cstring, x, y: i32, font_size: i32, color: game.Color) {
	rl.DrawText(msg, x, y, font_size, rl.Color(color))
}
