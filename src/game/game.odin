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
	last_frame_id:    int,

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


ctx: ^Context
g_mem: ^GameMemory

@(export)
game_init :: proc() {
	g_mem = new(GameMemory)
}

@(export)
game_setup :: proc(incoming_ctx: ^Context) {
	ctx = incoming_ctx

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
	return ctx.cmds.should_close_game()
}

@(export)
game_draw :: proc(ctx: ^Context) {
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
	new_mem := new(GameMemory)
	new_mem^ = g_mem^
	new_mem.bricks = make([]Brick, len(g_mem.bricks))
	copy(new_mem.bricks, g_mem.bricks)


	return new_mem
}

@(export)
game_delete_copy :: proc(mem: ^GameMemory) {
	delete(mem.bricks)
	free(mem)
}

