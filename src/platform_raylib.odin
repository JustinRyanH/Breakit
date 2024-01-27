package main

import "core:fmt"
import "core:math/linalg"

import rl "vendor:raylib"

import "game"

platform_new_context :: proc() -> ^game.Context {
	ctx := new(game.Context)
	ctx.frame = platform_update_frame(ctx.frame)
	setup_raylib_platform(&ctx.cmds)
	return ctx
}

deinit_game_context :: proc(ctx: ^game.Context) {
	free(ctx)
}

platform_update_frame :: proc(previous_frame: game.FrameInput) -> (new_frame: game.FrameInput) {
	new_frame.last_frame = previous_frame.current_frame
	new_frame.current_frame = collect_user_input(new_frame.last_frame.meta.frame_id + 1)
	return new_frame
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

@(private = "file")
collect_user_input :: proc(frame_id: int) -> (new_input: game.UserInput) {
	new_input.meta = game.FrameMeta {
		frame_id,
		rl.GetFrameTime(),
		cast(f32)rl.GetScreenWidth(),
		cast(f32)rl.GetScreenHeight(),
	}
	new_input.left_down = rl.IsKeyDown(.LEFT)
	new_input.right_down = rl.IsKeyDown(.RIGHT)
	new_input.space_down = rl.IsKeyDown(.SPACE)

	return new_input
}
