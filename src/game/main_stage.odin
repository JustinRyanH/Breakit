package game

import math "core:math/linalg"

import "input"

main_stage_update :: proc(stage: MainStage, frame_input: input.FrameInput) {
	ball_collision_targets = make([dynamic]CollidableObject, 0, 32, context.temp_allocator)
	ball_targets := data_pool_new_iter(&g_mem.entities)
	for entity, handle in data_pool_iter(&ball_targets) {
		#partial switch e in entity {
		case Brick:
			append(&ball_collision_targets, CollidableObject{.Brick, e.id, e.shape})
		case Paddle:
			append(&ball_collision_targets, CollidableObject{.Paddle, e.id, e.shape})
		case Wall:
			append(&ball_collision_targets, CollidableObject{.Wall, e.id, e.shape})

		}
	}

	main_stage_update_paddle(stage, frame_input)
	main_stage_update_ball(stage, frame_input)
}

setup_and_add_paddle :: proc(stage: ^MainStage) {
	ptr, handle, success := data_pool_add_empty(&g_mem.entities)
	if !success {
		panic("Failed to create Paddle Entity")
	}
	paddle := Paddle{}
	paddle.shape.pos = Vector2{g_mem.scene_width / 2, g_mem.scene_height - 50}
	paddle.shape.size = Vector2{100, 20}
	paddle.color = BLUE
	paddle.speed = 300
	paddle.id = handle
	ptr^ = paddle
	stage.paddle = handle
}

setup_and_add_ball :: proc(stage: ^MainStage) {
	ptr, handle, success := data_pool_add_empty(&g_mem.entities)
	if !success {
		panic("Failed to create Ball Entity")
	}
	ball := Ball{}
	ball.id = handle
	ball.shape.radius = 10
	ball.color = RED
	ball.state = LockedToEntity{stage.paddle, Vector2{0, -20}}
	ptr^ = ball
	stage.ball = handle
}

setup_main_stage :: proc(stage: ^MainStage) {
	width, height := g_mem.scene_width, g_mem.scene_height

	setup_and_add_paddle(stage)
	setup_and_add_ball(stage)

	wall_thickness: f32 = 100
	walls: []Wall =  {
		Wall {
			0,
			Rectangle {
				Vector2{(-wall_thickness / 2) + 5, height / 2},
				Vector2{wall_thickness, height},
				0.0,
			},
		},
		Wall {
			0,
			Rectangle {
				Vector2{width + (wall_thickness / 2) - 5, height / 2},
				Vector2{wall_thickness, height},
				0.0,
			},
		},
		Wall {
			0,
			Rectangle{Vector2{width / 2, wall_thickness / 2}, Vector2{width, wall_thickness}, 0.0},
		},
	}

	for wall in walls {
		ptr, h, success := data_pool_add_empty(&g_mem.entities)
		if !success {
			panic("Failed to create Wall Entity")
		}
		w_copy := wall
		w_copy.id = h
		ptr^ = w_copy
	}

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

		e_ptr, h, success := data_pool_add_empty(&g_mem.entities)
		if !success {
			panic("Failed to create Brick Entity")
		}
		brick := Brick {
			h,
			Rectangle{pos, Vector2{brick_width - gap, brick_height - gap}, 0},
			Color{255, 0, 0, 128},
			true,
		}
		e_ptr^ = brick
	}
}

main_stage_update_paddle :: proc(stage: MainStage, frame_input: input.FrameInput) {
	// This happens a lot. I should create a method where it panics
	// for each of the types I wanna pull
	paddle := get_paddle(&g_mem.entities, stage.paddle)

	dt := input.frame_query_delta(frame_input)
	scene_width, scene_height := g_mem.scene_width, g_mem.scene_height

	if (input.is_pressed(frame_input, KbKey.LEFT)) {
		paddle.shape.pos -= Vector2{1, 0} * paddle.speed * dt
	}
	if (input.is_pressed(frame_input, KbKey.RIGHT)) {
		paddle.shape.pos += Vector2{1, 0} * paddle.speed * dt
	}

	if (paddle.shape.pos.x - paddle.shape.size.x / 2 < 0) {
		paddle.shape.pos.x = paddle.shape.size.x / 2
	}

	if (paddle.shape.pos.x + paddle.shape.size.x / 2 > scene_width - 0) {
		paddle.shape.pos.x = g_mem.scene_width - paddle.shape.size.x / 2
	}
}

main_stage_update_ball :: proc(stage: MainStage, frame_input: input.FrameInput) {
	ball := get_ball(&g_mem.entities, stage.ball)

	dt := input.frame_query_delta(frame_input)


	switch bs in &ball.state {
	case LockedToEntity:
		paddle := get_paddle(&g_mem.entities, bs.handle)
		ball.shape.pos = paddle.shape.pos + bs.offset

		if input.is_pressed(frame_input, .SPACE) {
			evt := BeginFreeMovement{stage.ball, Vector2{0, -1}, 350}
			ring_buffer_append(&g_mem.event_queue, evt)
		}
	case FreeMovement:
		bs.direction = math.normalize(bs.direction)
		// We can slip through objects, so we should eventually do a raycast
		ball.shape.pos += bs.direction * bs.speed * dt

		for collidable in ball_collision_targets {
			switch collidable.kind {
			case .Ball, .Brick, .Wall:
				evt, is_colliding := shape_check_collision(ball.shape, collidable.shape)
				if is_colliding {
					entity, exists := data_pool_get(&g_mem.entities, collidable.handle)
					if (!exists) {
						continue
					}
					_, is_brick := entity.(Brick)
					if is_brick {
						ring_buffer_append(&g_mem.event_queue, DestroyEvent{collidable.handle})
					}
					bs.direction = bounce_normal(bs.direction, evt.normal)
					ball.shape.pos += evt.normal * evt.depth
				}
			case .Paddle:
				evt, is_colliding := shape_check_collision(ball.shape, collidable.shape)
				if (is_colliding) {
					paddle_rect, ok := collidable.shape.(Rectangle)
					if !ok {
						panic("Rect Shape should be a shape")
					}
					bs.direction.x =
						(ball.shape.pos.x - paddle_rect.pos.x) / (paddle_rect.size.x / 2)
					if (bs.direction.y > 0) {bs.direction.y *= -1}
					ball.shape.pos += evt.normal * evt.depth
				}
			}
		}

		height := g_mem.scene_height
		if (ball.shape.pos.y - ball.shape.radius * 3 > height) {
			ring_buffer_append(&g_mem.event_queue, BallDeathEvent{stage.ball})
		}
	}
}

get_ball :: proc(pool: ^DataPool($N, Entity, EntityHandle), handle: EntityHandle) -> ^Ball {
	ball_ptr := data_pool_get_ptr(pool, handle)
	if ball_ptr == nil {
		panic("Ball should always exists")
	}
	ball, is_ball := &ball_ptr.(Ball)
	if !is_ball {
		panic("Ball should also be a Ball")
	}
	return ball
}


get_paddle :: proc(pool: ^DataPool($N, Entity, EntityHandle), handle: EntityHandle) -> ^Paddle {
	paddle_ptr := data_pool_get_ptr(pool, handle)
	if paddle_ptr == nil {
		panic("Ball should always exists")
	}
	paddle, is_paddle := &paddle_ptr.(Paddle)
	if !is_paddle {
		panic("Ball should also be a Ball")
	}
	return paddle
}
