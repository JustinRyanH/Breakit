package main

import "core:fmt"
import math "core:math/linalg"

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
	cmd.draw_shape = raylib_draw_shape

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

raylib_draw_shape :: proc(shape: game.Shape, color: game.Color) {
	switch s in shape {
	case game.Circle:
		rl.DrawCircleV(s.pos, s.radius, cast(rl.Color)(color))
	case game.Rectangle:
		origin := s.size * 0.5
		rl_rect: rl.Rectangle = {s.pos.x, s.pos.y, s.size.x, s.size.y}
		rl.DrawRectanglePro(rl_rect, origin, s.rotation, cast(rl.Color)(color))
	case game.Line:
		rl.DrawLineEx(s.start, s.end, s.thickness, cast(rl.Color)(color))
	}
}

@(private = "file")
collect_user_input :: proc(frame_id: int) -> (new_input: game.UserInput) {
	new_input.meta = game.FrameMeta {
		frame_id,
		rl.GetFrameTime(),
		cast(f32)rl.GetScreenWidth(),
		cast(f32)rl.GetScreenHeight(),
	}
	new_input.keyboard.left_down = rl.IsKeyDown(.LEFT)
	new_input.keyboard.right_down = rl.IsKeyDown(.RIGHT)
	new_input.keyboard.space_down = rl.IsKeyDown(.SPACE)

	new_input.mouse.pos = cast(math.Vector2f32)(rl.GetMousePosition())
	new_input.mouse.left_down = rl.IsMouseButtonDown(.LEFT)
	new_input.mouse.right_down = rl.IsMouseButtonDown(.RIGHT)

	return new_input
}
