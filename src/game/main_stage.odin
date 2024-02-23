package game

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

setup_next_stage :: proc(stage: Stages) {
	main_stage, ok := stage.(MainStage)
	if !ok {
		panic("Not main stage")
	}
	g_mem.stages = main_stage
}
