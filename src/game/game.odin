package game

import "core:fmt"
import math "core:math/linalg"
import rl "vendor:raylib"

Vec2 :: math.Vector2f32

GameMemory :: struct {
	ctx:             ^Context,
	paddle_position: Vec2,
	paddle_size:     Vec2,
}


g_mem: ^GameMemory

@(export)
game_init :: proc() {
	g_mem = new(GameMemory)
}

@(export)
game_setup :: proc(ctx: ^Context) {
	meta := ctx.frame.current_frame.meta
	g_mem.paddle_position = {meta.screen_width / 2.0, meta.screen_height - 25}
	g_mem.paddle_size = {100, 20}
}

@(export)
game_update :: proc(ctx: ^Context) -> bool {
	g_mem.ctx = ctx
	game := g_mem


	input := ctx.frame
	cmds := game.ctx.cmds
	dt := get_frame_time(input)

	screen_width := ctx.frame.current_frame.meta.screen_width


	ball_speed: f32 = 275
	if is_right_arrow_down(input) {
		game.paddle_position.x += ball_speed * dt
	}
	if is_left_arrow_down(input) {
		game.paddle_position.x -= ball_speed * dt
	}
	if (game.paddle_position.x <= game.paddle_size.x / 2) {
		game.paddle_position.x = game.paddle_size.x / 2
	}

	if (game.paddle_position.x >= screen_width - game.paddle_size.x / 2) {
		game.paddle_position.x = screen_width - game.paddle_size.x / 2
	}

	return cmds.should_close_game()
}

@(export)
game_draw :: proc(platform_draw: ^PlatformDrawCommands) {
	game := g_mem
	platform_draw.begin_drawing()
	defer platform_draw.end_drawing()
	platform_draw.clear(BLACK)

	rect := Rectangle{game.paddle_position, game.paddle_size}
	platform_draw.draw_rect(rect, {50, 15}, 0, BLUE)


	platform_draw.draw_text("Breakit", 10, 56 / 3, 56, RED)
}

@(export)
game_shutdown :: proc() {
	free(g_mem)
}

@(export)
game_memory :: proc() -> rawptr {
	return g_mem
}

@(export)
game_hot_reloaded :: proc(mem: ^GameMemory) {
	g_mem = mem
}
