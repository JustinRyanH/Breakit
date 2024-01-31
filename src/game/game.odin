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

// TODO: Create a teardown so I can de-allocate if I recall setup
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

// Desired Order:
// - Input
// - Movements
// - Collision Detection
// - Collision Response
// - Constraints
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
	ball := &game.ball
	paddle := &game.paddle


	ball_speed: f32 = 500
	if input_is_right_arrow_down(input) {
		paddle.pos.x += ball_speed * dt
	}
	if input_is_left_arrow_down(input) {

	}
	game.ball.pos += game.ball_direction * game.ball_speed * dt

	if (ball.pos.y > ctx.frame.current_frame.meta.screen_height) {
		reset_ball()
	}

	if (shape_check_collision(ball^, game.paddle)) {
		if (game.ball_direction.y > 0.0) {
			game.ball_direction.y = -game.ball_direction.y
		}
		game.ball_direction.x = (ball.pos.x - game.paddle.pos.x) / (game.paddle.size.x / 2)
		game.ball_direction = math.normalize(game.ball_direction)
	}

	paddle.pos.x = math.clamp(paddle.pos.x, paddle.size.x / 2, screen_width - paddle.size.x / 2)
	ball.pos.x = math.clamp(ball.pos.x, ball.radius, screen_width - ball.radius)
	ball.pos.y = math.max(ball.pos.y, ball.radius)

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

	platform_draw.draw_shape(game.ball, RED)
	platform_draw.draw_shape(game.paddle, BLUE)

	platform_draw.draw_text(fmt.ctprintf("POS:%v", game.ball.pos), 100, 100, 20, MAROON)
	platform_draw.draw_text(fmt.ctprintf("SCREEN:%0.2f", screen_width), 100, 140, 20, MAROON)
}


@(export)
game_teardown :: proc() {
}

@(export)
game_shutdown :: proc() {
	game_teardown()
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
