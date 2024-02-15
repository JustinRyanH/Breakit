package game

import "core:fmt"
import math "core:math/linalg"

import "./input"

import mu "../microui"

Vec2 :: math.Vector2f32

BallState :: enum {
	OnPaddle,
	Moving,
}

Brick :: struct {
	alive: bool,
	rect:  Rectangle,
}

LineOfBricks :: 7
BricksPerLine :: 5
InitialDownOffset :: 50.0

GameMemory :: struct {
	ctx:              ^Context,
	// Entities
	paddle:           Rectangle,
	paddle_direction: Vec2,
	paddle_speed:     f32,
	ball:             Circle,
	paddle_velocity:  Vec2,
	ball_direction:   Vec2,
	ball_speed:       f32,
	ball_state:       BallState,

	// World
	bricks:           []Brick,
	active_bricks:    int,

	// World Stuff
	camera:           Camera2D,
}


g_mem: ^GameMemory

@(export)
game_init :: proc() {
	g_mem = new(GameMemory)
}

@(export)
game_setup :: proc(ctx: ^Context) {
	meta := ctx.frame.current_frame.meta
	screen_width, screen_height := input.frame_query_dimensions(ctx.frame)


	g_mem.camera.zoom = 1

	brick_size := Vec2{screen_width / BricksPerLine, 40}
	paddle_position := Vec2{screen_width / 2.0, screen_height - 25}
	paddle_size := Vec2{100, 20}

	g_mem.paddle = Rectangle{paddle_position, paddle_size, 0.0}
	g_mem.paddle_speed = 500

	g_mem.ball = Circle{Vec2{screen_width / 2.0, screen_height / 2.0}, 10}
	g_mem.ball_direction = math.vector_normalize(Vec2{100, 100})
	g_mem.ball_speed = 300
	g_mem.ball_state = BallState.OnPaddle
	g_mem.bricks = make([]Brick, LineOfBricks * BricksPerLine)

	for y := 0; y < LineOfBricks; y += 1 {
		for x := 0; x < BricksPerLine; x += 1 {
			pos := Vec2 {
				cast(f32)(x) * brick_size.x + brick_size.x / 2.0,
				cast(f32)(y) * brick_size.y + InitialDownOffset,
			}

			brick := Brick{true, Rectangle{pos, brick_size - Vec2{8, 8}, 0.0}}
			insert_index := BricksPerLine * y + x
			g_mem.bricks[insert_index] = brick
		}
	}
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

	ctx := game.ctx
	cmds := game.ctx.cmds
	dt := input.frame_query_delta(ctx.frame)

	mouse_pos := input.input_mouse_position(ctx.frame)
	screen_width, screen_height := input.frame_query_dimensions(ctx.frame)
	ball := &game.ball
	paddle := &game.paddle


	if input.input_is_right_arrow_down(ctx.frame) {
		game.paddle_velocity.x = 1
	} else if input.input_is_left_arrow_down(ctx.frame) {
		game.paddle_velocity.x = -1
	} else {
		game.paddle_velocity.x = 0
	}

	if input.input_was_space_pressed(ctx.frame) && game.ball_state == .OnPaddle {
		game.ball_direction = math.normalize(Vec2{0, 0.9})
		game.ball_state = BallState.Moving
	}

	game.paddle.pos += game.paddle_velocity * game.paddle_speed * dt
	switch game.ball_state {
	case .OnPaddle:
		ball.pos.x = paddle.pos.x
		ball.pos.y = paddle.pos.y - paddle.size.y / 2 - ball.radius
	case .Moving:
		game.ball.pos += game.ball_direction * game.ball_speed * dt
	}

	_, did_collide := shape_check_collision(ball^, game.paddle)
	if (did_collide) {
		if (game.ball_direction.y > 0.0) {
			game.ball_direction.y = -game.ball_direction.y
		}
		game.ball_direction.x = (ball.pos.x - game.paddle.pos.x) / (game.paddle.size.x / 2)
		game.ball_direction = math.normalize(game.ball_direction)
	}

	world := Rectangle {
		Vec2{screen_width / 2, screen_height / 2},
		Vec2{screen_width, screen_height},
		0.0,
	}
	world_edges := shape_get_rect_lines(world)
	for i := 0; i < len(world_edges); i += 1 {
		edge := world_edges[i]
		edge = shape_invert_line(edge)
		edge.thickness = 2

		contact_evt, did_collide := shape_check_collision(ball^, edge)
		if (did_collide) {
			platform_debug_draw_collision(contact_evt)
			normal := contact_evt.normal
			if (math.abs(normal.x) > 0) {
				game.ball_direction.x = -game.ball_direction.x
				break
			}
			if (normal.y > 0) {
				game.ball_direction.y = -game.ball_direction.y
				break
			}
		}
	}

	for i := 0; i < len(game.bricks); i += 1 {
		brick := &game.bricks[i]
		if (!brick.alive) {
			continue
		}
		rect_evt, did_collide := shape_check_collision(ball^, brick.rect)
		if (did_collide) {
			if (ctx.frame.debug_draw) {platform_debug_draw_collision(rect_evt)}
			brick.alive = false
			normal := rect_evt.normal
			game.ball.pos += normal * rect_evt.depth
			if (math.abs(normal.x) > 0) {
				game.ball_direction.x = -game.ball_direction.x
				break
			}
			if (math.abs(normal.y) > 0) {
				game.ball_direction.y = -game.ball_direction.y
				break
			}
		}
	}


	if (ball.pos.y - ball.radius * 2 > screen_height) {
		reset_ball()
	}

	paddle.pos.x = math.clamp(paddle.pos.x, paddle.size.x / 2, screen_width - paddle.size.x / 2)
	ball.pos.x = math.clamp(ball.pos.x, ball.radius, screen_width - ball.radius)
	ball.pos.y = math.max(ball.pos.y, ball.radius)


	return ctx.cmds.should_close_game()
}

@(export)
game_draw :: proc(platform_draw: ^PlatformDrawCommands) {
	game := g_mem
	frame := game.ctx.frame

	platform_draw.begin_drawing()
	defer platform_draw.end_drawing()

	platform_draw.clear(BLACK)

	platform_draw.draw_shape(game.ball, RED)
	platform_draw.draw_shape(game.paddle, BLUE)
	for brick in game.bricks {
		if (!brick.alive) {
			continue
		}
		platform_draw.draw_shape(brick.rect, ORANGE)
	}

	game_draw_debug(platform_draw)

	{
		mui_ctx := &game.ctx.mui
		mu.begin(mui_ctx)
		defer mu.end(mui_ctx)

		if (frame.debug) {
			mu.window(mui_ctx, "Window", {200, 200, 200, 200}, {.NO_CLOSE})
			mu.layout_row(mui_ctx, {100})
			res := mu.button(mui_ctx, "Replay")

			if .SUBMIT in res {
				game.ctx.debug_cmds.replay_current_game()
			}
		}

	}
	platform_draw.draw_mui(&game.ctx.mui)
}

game_draw_debug :: proc(platform_draw: ^PlatformDrawCommands) {
	game := g_mem
	if (!game.ctx.frame.debug_draw) {
		return
	}

	screen_width, screen_height := input.frame_query_dimensions(game.ctx.frame)

	world := Rectangle {
		Vec2{screen_width / 2, screen_height / 2},
		Vec2{screen_width, screen_height},
		0.0,
	}
	world_edges := shape_get_rect_lines(world)
	for i := 0; i < len(world_edges); i += 1 {
		edge := world_edges[i]
		edge.thickness = 2

		projection_point := shape_point_projected_to_line(game.ball.pos, edge)
		normal := shape_line_normal(edge)
		offset := projection_point - (normal * 100)
		platform_draw.draw_shape(
			Line{projection_point, projection_point - (normal * 20), 2},
			GREEN,
		)
		platform_draw.draw_text(
			fmt.ctprintf("N(%v)", -normal),
			cast(i32)(offset.x),
			cast(i32)(offset.y),
			20,
			MAROON,
		)
		platform_draw.draw_shape(edge, GREEN)
	}

	for i := 0; i < len(world_edges); i += 1 {
		edge_normal := shape_line_normal(world_edges[i])
		edge := world_edges[i]
		edge = shape_invert_line(edge)
		edge.thickness = 2


		edge.start = edge.start - (edge_normal * 10)
		edge.end = edge.end - (edge_normal * 10)

		platform_draw.draw_shape(edge, GREEN)
	}
}

@(export)
game_shutdown :: proc() {
	delete(g_mem.bricks)
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

@(export)
game_copy_memory :: proc() -> rawptr {
	return g_mem
}

@(export)
game_delete_copy :: proc(mem: ^GameMemory) {
	delete(mem.bricks)
	free(mem)
}


//////////////////////////////////////////
// Game Functions
//////////////////////////////////////////


update_game_normal :: proc() {
	game := g_mem

}

reset_ball :: proc() {
	meta := g_mem.ctx.frame.current_frame.meta

	g_mem.ball = Circle{Vec2{meta.screen_width / 2.0, meta.screen_height / 2.0}, 10}
	g_mem.ball_direction = math.vector_normalize(Vec2{100, 100})
	g_mem.ball_speed = 300
	paddle_position := Vec2{meta.screen_width / 2.0, meta.screen_height - 25}
	g_mem.paddle.pos = paddle_position
	g_mem.ball_state = .OnPaddle

	for _, i in g_mem.bricks {
		g_mem.bricks[i].alive = true
	}
}
