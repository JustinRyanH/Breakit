package game

import "core:fmt"
import math "core:math/linalg"
import rl "vendor:raylib"

Vec2 :: math.Vector2f32

GameMemory :: struct {
	ctx:    ^Context,
	paddle: Rectangle,
}


g_mem: ^GameMemory

@(export)
game_init :: proc() {
	g_mem = new(GameMemory)
}

@(export)
game_setup :: proc(ctx: ^Context) {
	meta := ctx.frame.current_frame.meta
	paddle_position := Vec2{meta.screen_width / 2.0, meta.screen_height - 25}
	paddle_size := Vec2{100, 20}

	g_mem.paddle = Rectangle{paddle_position, paddle_size, 0.0}

}

@(export)
game_update :: proc(ctx: ^Context) -> bool {
	g_mem.ctx = ctx
	game := g_mem


	input := ctx.frame
	cmds := game.ctx.cmds
	dt := get_frame_time(input)

	screen_width := ctx.frame.current_frame.meta.screen_width
	paddle := &game.paddle


	ball_speed: f32 = 500
	if is_right_arrow_down(input) {
		paddle.pos.x += ball_speed * dt
	}
	if is_left_arrow_down(input) {
		paddle.pos.x -= ball_speed * dt
	}
	if (paddle.pos.x <= paddle.size.x / 2) {
		paddle.pos.x = paddle.size.x / 2
	}

	if (paddle.pos.x >= screen_width - paddle.size.x / 2) {
		paddle.pos.x = screen_width - paddle.size.x / 2
	}

	return cmds.should_close_game()
}

@(export)
game_draw :: proc(platform_draw: ^PlatformDrawCommands) {
	game := g_mem
	platform_draw.begin_drawing()
	defer platform_draw.end_drawing()
	platform_draw.clear(BLACK)

	platform_draw.draw_shape(game.paddle, BLUE)


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
