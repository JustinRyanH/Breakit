package main

import "core:fmt"
import "core:math/linalg"

import rl "vendor:raylib"

import "game"

allocat_and_init_game_context :: proc() -> ^game.Context {
	ctx := new(game.Context)
	setup_raylib_platform(&ctx.platform_cmds)
	return ctx
}

deinit_game_context :: proc(ctx: ^game.Context) {
	free(ctx)
}

setup_raylib_platform :: proc(cmds: ^game.PlatformCommands) {
	cmds.should_close_game = cast(proc() -> bool)(rl.WindowShouldClose)
}

build_raylib_platform_draw :: proc() -> ^game.PlatformDrawCommands {
	cmd := new(game.PlatformDrawCommands)
	cmd.begin_drawing = cast(proc())(rl.BeginDrawing)
	cmd.end_drawing = cast(proc())(rl.EndDrawing)
	cmd.clear = raylib_clear_background
	cmd.draw_text = raylib_draw_text
	cmd.draw_rect = raylib_draw_rectangle
	cmd.draw_circle = raylib_draw_circle

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

raylib_draw_rectangle :: proc(
	rect: game.Rectangle,
	origin: linalg.Vector2f32,
	rotation: f32,
	color: game.Color,
) {
	rl.DrawRectanglePro(cast(rl.Rectangle)(rect), origin, rotation, cast(rl.Color)(color))
}

raylib_draw_circle :: proc(pos: linalg.Vector2f32, radius: f32, color: game.Color) {
	rl.DrawCircleV(pos, radius, cast(rl.Color)(color))
}
