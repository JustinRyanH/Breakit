package game

import "core:fmt"
import math "core:math/linalg"
import rl "vendor:raylib"

Vec2 :: math.Vector2f32

GameMemory :: struct {
	ctx:            ^Context,
	paddle:         Rectangle,
	ball:           Circle,
	ball_direction: Vec2,
	ball_speed:     f32,

	// World Stuff
	camera:         Camera2D,
}


g_mem: ^GameMemory

@(export)
game_init :: proc() {
	g_mem = new(GameMemory)
}

@(export)
game_setup :: proc(ctx: ^Context) {
	meta := ctx.frame.current_frame.meta
	g_mem.camera.zoom = 1

	paddle_position := Vec2{meta.screen_width / 2.0, meta.screen_height - 25}
	paddle_size := Vec2{100, 20}

	g_mem.paddle = Rectangle{paddle_position, paddle_size, 0.0}

	g_mem.ball = Circle{Vec2{meta.screen_width / 2.0, meta.screen_height / 2.0}, 10}
	g_mem.ball_direction = math.vector_normalize(Vec2{100, 100})
	g_mem.ball_speed = 300
}

@(export)
game_update :: proc(ctx: ^Context) -> bool {
	g_mem.ctx = ctx
	game := g_mem

	input := ctx.frame
	cmds := game.ctx.cmds
	dt := frame_query_delta(input)

	mouse_pos := input_mouse_position(ctx.frame)
	screen_width := ctx.frame.current_frame.meta.screen_width
	screen_height := ctx.frame.current_frame.meta.screen_height
	paddle := &game.paddle

	ball_speed: f32 = 500
	if input_is_right_arrow_down(input) {
		paddle.pos.x += ball_speed * dt
	}
	if input_is_left_arrow_down(input) {
		paddle.pos.x -= ball_speed * dt
	}
	if (paddle.pos.x <= paddle.size.x / 2) {
		paddle.pos.x = paddle.size.x / 2
	}

	if (paddle.pos.x >= screen_width - paddle.size.x / 2) {
		paddle.pos.x = screen_width - paddle.size.x / 2
	}

	game.ball.pos += game.ball_direction * game.ball_speed * dt
	if (game.ball.pos.y > ctx.frame.current_frame.meta.screen_height) {
		reset_ball()
	}


	return cmds.should_close_game()
}

@(export)
game_draw :: proc(platform_draw: ^PlatformDrawCommands) {
	game := g_mem

	screen_width := game.ctx.frame.current_frame.meta.screen_width
	screen_height := game.ctx.frame.current_frame.meta.screen_height

	platform_draw.begin_drawing()
	defer platform_draw.end_drawing()

	platform_draw.clear(BLACK)
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


//////////////////////////////////////////
// Game Functions
//////////////////////////////////////////


reset_ball :: proc() {
	meta := g_mem.ctx.frame.current_frame.meta

	g_mem.ball = Circle{Vec2{meta.screen_width / 2.0, meta.screen_height / 2.0}, 10}
	g_mem.ball_direction = math.vector_normalize(Vec2{100, 100})
	g_mem.ball_speed = 300
}
