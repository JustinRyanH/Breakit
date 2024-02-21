package game

import sa "core:container/small_array"
import "core:fmt"
import math "core:math/linalg"
import "core:math/rand"
import "core:mem"

import "./input"

import mu "../microui"


KbKey :: input.KeyboardKey
MouseBtn :: input.MouseButton

ObjectKind :: enum {
	Ball,
	Brick,
	Wall,
	Paddle,
}

BrickHandle :: distinct Handle

HandleUnion :: union {
	Handle,
	BrickHandle,
	EntityHandle,
}

CollidableObject :: struct {
	kind:   ObjectKind,
	handle: HandleUnion,
	shape:  Shape,
}

Paddle :: struct {
	shape: Rectangle,
	color: Color,
	speed: f32,
}

Wall :: struct {
	id:    EntityHandle,
	shape: Rectangle,
}

BallState :: enum {
	LockedToPaddle,
	Free,
}

Brick :: struct {
	id:    EntityHandle,
	shape: Rectangle,
	color: Color,
	alive: bool,
}

Ball :: struct {
	id:        EntityHandle,
	shape:     Circle,
	color:     Color,
	state:     BallState,
	direction: Vector2,
	speed:     Vector2,
}

EntityHandle :: distinct Handle
Entity :: struct {}

GameMemory :: struct {
	scene_width:  f32,
	scene_height: f32,

	// Game Entities
	paddle:       Paddle,
	ball:         Ball,
	bounds:       sa.Small_Array(16, Wall),
	bricks:       DataPool(256, Brick, BrickHandle),
	entities:     DataPool(512, Entity, EntityHandle),
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
	data_pool_reset(&g_mem.bricks)
	data_pool_reset(&g_mem.entities)
	sa.clear(&g_mem.bounds)

	g_mem.scene_width = 800
	g_mem.scene_height = 600
	width, height := g_mem.scene_width, g_mem.scene_height
	g_mem.paddle.shape.pos = Vector2{g_mem.scene_width / 2, g_mem.scene_height - 50}
	g_mem.paddle.shape.size = Vector2{100, 20}
	g_mem.paddle.color = BLUE
	g_mem.paddle.speed = 300

	handle, success := data_pool_add(&g_mem.entities, Entity{})
	if !success {
		panic("Failed to create Ball Entity")
	}
	g_mem.ball.id = handle
	g_mem.ball.shape.pos = g_mem.paddle.shape.pos + Vector2{0, -20}
	g_mem.ball.shape.radius = 10
	g_mem.ball.color = RED
	g_mem.ball.state = .LockedToPaddle
	g_mem.ball.speed = 350

	wall_thickness: f32 = 100

	handle, success = data_pool_add(&g_mem.entities, Entity{})
	if !success {
		panic("Failed to create Ball Entity")
	}
	sa.append(
		&g_mem.bounds,
		Wall {
			handle,
			Rectangle {
				Vector2{(-wall_thickness / 2) + 5, height / 2},
				Vector2{wall_thickness, height},
				0.0,
			},
		},
	)

	handle, success = data_pool_add(&g_mem.entities, Entity{})
	if !success {
		panic("Failed to create Ball Entity")
	}
	sa.append(
		&g_mem.bounds,
		Wall {
			handle,
			Rectangle {
				Vector2{width + (wall_thickness / 2) - 5, height / 2},
				Vector2{wall_thickness, height},
				0.0,
			},
		},
	)

	handle, success = data_pool_add(&g_mem.entities, Entity{})
	if !success {
		panic("Failed to create Ball Entity")
	}
	sa.append(
		&g_mem.bounds,
		Wall {
			handle,
			Rectangle{Vector2{width / 2, wall_thickness / 2}, Vector2{width, wall_thickness}, 0.0},
		},
	)


	brickable_area: Rectangle
	brickable_area.pos = Vector2{width / 2, height / 2 - 35}
	brickable_area.size = Vector2{788, 250}
	brickable_area_min, brickable_area_max := shape_get_rect_extends(brickable_area)

	gap: f32 = 2
	bricks_per_row: int = 7
	bricks_per_column: int = 7

	brick_width: f32 = (brickable_area.size.x / cast(f32)bricks_per_row)
	brick_height: f32 = (brickable_area.size.y / cast(f32)bricks_per_column)


	for idx in 0 ..< (bricks_per_row * bricks_per_column) {
		x_index := idx % bricks_per_row
		y_index := idx / bricks_per_row

		pos := Vector2{cast(f32)x_index * brick_width, cast(f32)y_index * brick_height}
		pos += brickable_area_min + (Vector2{brick_width, brick_height} / 2)

		id, success := data_pool_add(&g_mem.entities, Entity{})
		if !success {
			panic("Failed to create Brick Entity")
		}
		brick := Brick {
			id,
			Rectangle{pos, Vector2{brick_width - gap, brick_height - gap}, 0},
			Color{255, 0, 0, 128},
			true,
		}
		_, success = data_pool_add(&g_mem.bricks, brick)
		if (!success) {
			panic(fmt.tprintf("Did not add data: %v", &g_mem.bricks))
		}
	}
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

	if (ctx.last_frame_id != get_frame_id(frame_input)) {
		update_gameplay(frame_input)
	}

	{
		mui_ctx := &ctx.mui
		mu.begin(mui_ctx)
		defer mu.end(mui_ctx)

		rp, is_replay := &ctx.playback.(input.Replay)
		if is_replay {
			mu.window(mui_ctx, "Replay Controls", {500, 100, 300, 175}, {.NO_CLOSE})
			mu.layout_row(mui_ctx, {-1})
			frame := cast(mu.Real)rp.index
			mu.slider(
				mui_ctx,
				&frame,
				0,
				cast(mu.Real)rp.last_frame_index,
				1,
				"%.0f",
				{.NO_INTERACT},
			)

			if (rp.active) {
				mu.layout_row(mui_ctx, {75})
				mu.checkbox(mui_ctx, "Active", &rp.active)
			} else {
				mu.layout_row(mui_ctx, {75, 50})
				mu.checkbox(mui_ctx, "Active", &rp.active)
				res := mu.button(mui_ctx, "Step")
				if .SUBMIT in res {
					append(&ctx.events, StepEvent{1})
				}
			}

			@(static)
			target_frame: mu.Real
			mu.layout_row(mui_ctx, {80, -1})
			res := mu.button(mui_ctx, "Jump to Frame")
			if .SUBMIT in res {
				append(&ctx.events, JumpToFrame{cast(int)target_frame})
			}
			mu.slider(mui_ctx, &target_frame, 0, cast(mu.Real)rp.last_frame_index, 1, "%.0f")

			mu.layout_row(mui_ctx, {80, 75, 75})
			res = mu.button(mui_ctx, "Loop Between")
			@(static)
			start_frame: mu.Real
			@(static)
			end_frame: mu.Real

			if (end_frame == 0) {
				end_frame = cast(mu.Real)rp.last_frame_index - 1
			}

			mu.slider(mui_ctx, &start_frame, 0, end_frame, 1, "From: %.0f")
			mu.slider(
				mui_ctx,
				&end_frame,
				start_frame,
				cast(mu.Real)rp.last_frame_index - 1,
				1,
				"To: %.0f",
			)
		}

	}

	ctx.last_frame_id = get_frame_id(frame_input)
	return ctx.cmds.should_close_game()
}

@(export)
game_draw :: proc() {
	game := g_mem
	width, height := g_mem.scene_width, g_mem.scene_height

	draw_cmds := &ctx.draw_cmds
	draw_cmds.clear(BLACK)

	draw_cmds.draw_shape(game.paddle.shape, game.paddle.color)
	draw_cmds.draw_shape(game.ball.shape, game.ball.color)
	for wall in sa.slice(&game.bounds) {
		draw_cmds.draw_shape(wall.shape, Color{36, 36, 32, 255})
	}

	brick_iter := data_pool_new_iter(&g_mem.bricks)
	for brick in data_pool_iter(&brick_iter) {
		draw_cmds.draw_shape(brick.shape, brick.color)
	}

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
	ball_collision_targets := make([dynamic]CollidableObject, 0, 32, context.temp_allocator)

	dt := input.frame_query_delta(frame_input)
	g_input = frame_input
	paddle := &g_mem.paddle
	ball := &g_mem.ball

	null_handle: Handle = 0

	append(&ball_collision_targets, CollidableObject{.Paddle, null_handle, paddle.shape})
	for wall in sa.slice(&g_mem.bounds) {
		append(&ball_collision_targets, CollidableObject{.Wall, null_handle, wall.shape})
	}

	brick_iter := data_pool_new_iter(&g_mem.bricks)
	for brick, handle in data_pool_iter(&brick_iter) {
		append(&ball_collision_targets, CollidableObject{.Brick, handle, brick.shape})
	}

	scene_width, scene_height := g_mem.scene_width, g_mem.scene_height

	if (input.is_pressed(frame_input, KbKey.LEFT)) {
		paddle.shape.pos -= Vector2{1, 0} * paddle.speed * dt
	}
	if (input.is_pressed(frame_input, KbKey.RIGHT)) {
		paddle.shape.pos += Vector2{1, 0} * paddle.speed * dt
	}

	is_locked_to_paddle := ball.state == .LockedToPaddle
	if (is_locked_to_paddle && input.is_pressed(frame_input, .SPACE)) {
		ball.state = .Free
		ball.direction = Vector2{0, -1}
	}

	if (paddle.shape.pos.x - paddle.shape.size.x / 2 < 0) {
		paddle.shape.pos.x = paddle.shape.size.x / 2
	}

	if (paddle.shape.pos.x + paddle.shape.size.x / 2 > scene_width - 0) {
		paddle.shape.pos.x = g_mem.scene_width - paddle.shape.size.x / 2
	}


	switch ball.state {
	case .LockedToPaddle:
		ball.shape.pos = paddle.shape.pos + Vector2{0, -20}
	case .Free:
		ball.direction = math.normalize(ball.direction)
		// We can slip through objects, so we should eventually do a raycast
		ball.shape.pos += ball.direction * ball.speed * dt

		for collidable in ball_collision_targets {
			switch collidable.kind {
			case .Ball, .Brick, .Wall:
				evt, is_colliding := shape_check_collision(ball.shape, collidable.shape)
				if is_colliding {
					brick_handle, is_brick := collidable.handle.(BrickHandle)
					if is_brick {
						removed := data_pool_remove(&g_mem.bricks, brick_handle)
						if !removed {
							fmt.println("Failed to remove brick at handle", brick_handle)
						}
					}
					ball.direction = bounce_normal(ball.direction, evt.normal)
					ball.shape.pos += evt.normal * evt.depth
				}
			case .Paddle:
				evt, is_colliding := shape_check_collision(ball.shape, collidable.shape)
				if (is_colliding) {
					ball.direction.x =
						(ball.shape.pos.x - paddle.shape.pos.x) / (paddle.shape.size.x / 2)
					if (ball.direction.y > 0) {ball.direction.y *= -1}
					ball.shape.pos += evt.normal * evt.depth
				}
			}
		}


		if (ball.shape.pos.y - ball.shape.radius * 3 > scene_height) {
			game_setup()
		}
	}

}


get_frame_id :: proc(frame_input: input.FrameInput) -> int {
	return frame_input.current_frame.meta.frame_id
}

bounce_normal :: #force_inline proc(dir: Vector2, normal: Vector2) -> Vector2 {
	surface_perp_projection := math.dot(dir, normal) * normal
	surface_axis := dir - surface_perp_projection

	return surface_axis - surface_perp_projection
}
