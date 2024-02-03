package game

import "core:fmt"
import math "core:math/linalg"

import rl "vendor:raylib"

Vec2 :: math.Vector2f32

BallState :: enum {
	OnPaddle,
	Moving,
}

Brick :: struct {
	alive: bool,
	rect:  Rectangle,
}

LineOfBricks :: 5
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
	rotation:         f32,

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
	screen_width, screen_height := frame_query_dimensions(ctx.frame)


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
	// update_game_normal()

	if (input_is_left_arrow_down(ctx.frame)) {
		game.rotation -= 1
	} else if (input_is_right_arrow_down(ctx.frame)) {
		game.rotation += 1
	}

	return ctx.cmds.should_close_game()
}

@(export)
game_draw :: proc(platform_draw: ^PlatformDrawCommands) {
	game := g_mem

	platform_draw.begin_drawing()
	defer platform_draw.end_drawing()

	platform_draw.clear(BLACK)

	screen_width, screen_height := frame_query_dimensions(game.ctx.frame)

	mouse_rect := Rectangle{input_mouse_position(game.ctx.frame), Vec2{50, 75}, game.rotation}
	static_rect := Rectangle{Vec2{400, 400}, Vec2{100, 200}, 0}

	if (mouse_rect.pos == Vec2{}) {
		platform_draw.draw_shape(static_rect, YELLOW)
		platform_draw.draw_shape(mouse_rect, PURPLE)
		return
	}

	platform_draw.draw_shape(static_rect, YELLOW)

	len := math.length(mouse_rect.size) / 2
	nm := math.normalize(mouse_rect.size)


	a_seperation, b_seperation := shape_rectangle_seperations(mouse_rect, static_rect)
	platform_draw.draw_text(
		fmt.ctprintf("Seperation: a(%v), b(%v)", a_seperation, b_seperation),
		10,
		10,
		20,
		WHITE,
	)


	platform_draw.draw_shape(mouse_rect, Color{135, 60, 190, 220})


	// mouse_rect_lines := shape_get_rect_lines(mouse_rect)
	// for line in mouse_rect_lines {
	// 	line_copy := line
	// 	line_copy.thickness = 2
	// 	platform_draw.draw_shape(line_copy, PURPLE)
	// }

	// evt_a, evt_b, did_collide := shape_are_rects_colliding(mouse_rect, static_rect)
	// if (did_collide) {
	// 	platform_draw.draw_shape(Circle{evt_a.pos, 4}, GREEN)
	// 	platform_draw.draw_shape(Circle{evt_b.pos, 4}, VIOLET)

	// 	platform_debug_draw_collision(platform_draw, evt_a, GREEN)
	// 	platform_debug_draw_collision(platform_draw, evt_b, VIOLET)
	// }


	// draw_game_normal(platform_draw)
	game_draw_debug(platform_draw)
}

draw_game_normal :: proc(platform_draw: ^PlatformDrawCommands) {
	game := g_mem
	platform_draw.draw_shape(game.ball, RED)
	platform_draw.draw_shape(game.paddle, BLUE)
	for brick in game.bricks {
		if (!brick.alive) {
			continue
		}
		platform_draw.draw_shape(brick.rect, ORANGE)
	}
}

game_draw_debug :: proc(platform_draw: ^PlatformDrawCommands) {
	game := g_mem
	if (!frame_query_debug(game.ctx.frame)) {
		return
	}

	screen_width, screen_height := frame_query_dimensions(game.ctx.frame)

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
}


@(export)
game_teardown :: proc() {
	delete(g_mem.bricks)
}

@(export)
game_shutdown :: proc() {
	game_teardown()
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


//////////////////////////////////////////
// Game Functions
//////////////////////////////////////////


update_game_normal :: proc() {
	game := g_mem

	ctx := game.ctx
	input := ctx.frame
	cmds := game.ctx.cmds
	dt := frame_query_delta(input)

	mouse_pos := input_mouse_position(ctx.frame)
	screen_width, screen_height := frame_query_dimensions(ctx.frame)
	ball := &game.ball
	paddle := &game.paddle


	if input_is_right_arrow_down(input) {
		game.paddle_velocity.x = 1
	} else if input_is_left_arrow_down(input) {
		game.paddle_velocity.x = -1
	} else {
		game.paddle_velocity.x = 0
	}

	if input_was_space_pressed(input) && game.ball_state == .OnPaddle {
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

	if (shape_check_collision(ball^, game.paddle)) {
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
		edge.thickness = 2

		if (shape_check_collision(ball^, edge)) {
			normal := -shape_line_normal(edge)
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
		if (shape_check_collision(ball^, brick.rect)) {
			brick.alive = false
			edges := shape_get_rect_lines(brick.rect)
			for j := 0; j < len(edges); j += 1 {
				edge := edges[j]
				normal := shape_line_normal(edge)
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
	}


	if (ball.pos.y - ball.radius * 2 > screen_height) {
		reset_ball()
	}

	paddle.pos.x = math.clamp(paddle.pos.x, paddle.size.x / 2, screen_width - paddle.size.x / 2)
	ball.pos.x = math.clamp(ball.pos.x, ball.radius, screen_width - ball.radius)
	ball.pos.y = math.max(ball.pos.y, ball.radius)

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
