package game

import "core:fmt"
import math "core:math/linalg"

import "./input"

import mu "../microui"

KbKey :: input.KeyboardKey
MouseBtn :: input.MouseButton

Paddle :: struct {
	shape: Rectangle,
	color: Color,
	speed: f32,
}

BallState :: enum {
	LockedToPaddle,
	Free,
}

Ball :: struct {
	shape:     Circle,
	color:     Color,
	state:     BallState,
	direction: Vector2,
	speed:     Vector2,
}

GameMemory :: struct {
	scene_width:  f32,
	scene_height: f32,

	// Game Entities
	paddle:       Paddle,
	ball:         Ball,
}


ctx: ^Context
g_input: input.FrameInput
g_mem: ^GameMemory

current_input :: #force_inline proc() -> input.UserInput {
	return g_input.current_frame
}

@(export)
game_init :: proc() {
	g_mem = new(GameMemory)
}

@(export)
game_setup :: proc() {
	g_mem.scene_width = 800
	g_mem.scene_height = 600
	g_mem.paddle.shape.pos = Vector2{g_mem.scene_width / 2, g_mem.scene_height - 50}
	g_mem.paddle.shape.size = Vector2{100, 20}
	g_mem.paddle.color = BLUE
	g_mem.paddle.speed = 300

	g_mem.ball.shape.pos = g_mem.paddle.shape.pos + Vector2{0, -20}
	g_mem.ball.shape.radius = 10
	g_mem.ball.color = RED
	g_mem.ball.state = .LockedToPaddle
	g_mem.ball.speed = 350
}

@(export)
game_update_context :: proc(new_ctx: ^Context) {
	ctx = new_ctx
}

@(export)
game_update :: proc(frame_input: input.FrameInput) -> bool {
	dt := input.frame_query_delta(frame_input)
	g_input = frame_input
	paddle := &g_mem.paddle
	ball := &g_mem.ball

	update_gameplay(frame_input)

	{
		mui_ctx := &ctx.mui
		mu.begin(mui_ctx)
		defer mu.end(mui_ctx)

		_, is_replay := ctx.playback.(input.Replay)
		if is_replay {
			mu.window(mui_ctx, "Replay Controls", {500, 100, 300, 100})
		}

	}

	return ctx.cmds.should_close_game()
}

@(export)
game_draw :: proc() {
	game := g_mem
	draw_cmds := &ctx.draw_cmds
	draw_cmds.clear(BLACK)

	draw_cmds.draw_shape(game.paddle.shape, game.paddle.color)
	draw_cmds.draw_shape(game.ball.shape, game.ball.color)

	draw_cmds.draw_text(fmt.ctprintf("%v", current_input().keyboard), 10, 40, 8, RAYWHITE)
	draw_cmds.draw_text(fmt.ctprintf("%v", current_input().mouse), 10, 60, 8, RAYWHITE)
	draw_cmds.draw_text(
		fmt.ctprintf("index: %v", current_input().meta.frame_id),
		10,
		84,
		12,
		RAYWHITE,
	)
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


update_gameplay :: proc(frame_input: input.FrameInput) {
	dt := input.frame_query_delta(frame_input)
	g_input = frame_input
	paddle := &g_mem.paddle
	ball := &g_mem.ball

	scene_width, scene_height := g_mem.scene_width, g_mem.scene_height

	if (input.is_pressed(frame_input, KbKey.LEFT)) {
		paddle.shape.pos -= Vector2{1, 0} * paddle.speed * dt
	}
	if (input.is_pressed(frame_input, KbKey.RIGHT)) {
		paddle.shape.pos += Vector2{1, 0} * paddle.speed * dt
	}

	if (input.is_pressed(frame_input, .SPACE)) {
		ball.state = .Free
		ball.direction = Vector2{0, -1}
	}

	if (paddle.shape.pos.x - paddle.shape.size.x / 2 < 0) {
		paddle.shape.pos.x = paddle.shape.size.x / 2
	}

	if (paddle.shape.pos.x + paddle.shape.size.x / 2 > scene_width) {
		paddle.shape.pos.x = g_mem.scene_width - paddle.shape.size.x / 2
	}


	switch ball.state {
	case .LockedToPaddle:
		ball.shape.pos = paddle.shape.pos + Vector2{0, -20}
	case .Free:
		ball.direction = math.normalize(ball.direction)
		ball.shape.pos += ball.direction * ball.speed * dt

		evt, is_colliding := shape_check_collision(
			ball.shape,
			Line{Vector2{}, Vector2{scene_width, 0}, 1.0},
		)
		if (is_colliding) {
			ball.direction.y *= -1
			ball.shape.pos -= evt.normal * evt.depth
		}

		evt, is_colliding = shape_check_collision(
			ball.shape,
			Line{Vector2{scene_width, 0}, Vector2{scene_width, scene_height}, 1.0},
		)
		if (is_colliding) {
			ball.direction.x *= -1
			ball.shape.pos -= evt.normal * evt.depth
		}

		evt, is_colliding = shape_check_collision(
			ball.shape,
			Line{Vector2{0, scene_height}, Vector2{0, 0}, 1.0},
		)
		if (is_colliding) {
			ball.direction.x *= -1
			ball.shape.pos -= evt.normal * evt.depth
		}

		evt, is_colliding = shape_check_collision(
			ball.shape,
			Line{Vector2{0, scene_height}, Vector2{scene_width, scene_height}, 1},
		)

		evt, is_colliding = shape_check_collision(ball.shape, paddle.shape)
		if (is_colliding) {
			ball.direction.x = (ball.shape.pos.x - paddle.shape.pos.x) / (paddle.shape.size.x / 2)
			ball.direction.y *= -1
			ball.shape.pos -= evt.normal * evt.depth
		}

		if (ball.shape.pos.y + ball.shape.radius > scene_height) {
			game_setup()
		}
	}

}
