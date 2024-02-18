package game

import sa "core:container/small_array"
import "core:fmt"
import math "core:math/linalg"
import "core:math/rand"

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
	bounds:       sa.Small_Array(16, Line),
}


ctx: ^Context
g_input: input.FrameInput
g_mem: ^GameMemory


DebugBox :: struct {
	shape: Rectangle,
	color: Color,
}

debug_boxes: [16]DebugBox
mouse_box: DebugBox


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

	sa.clear(&g_mem.bounds)
	sa.append(&g_mem.bounds, Line{Vector2{g_mem.scene_width - 30, 30}, Vector2{30, 30}, 1.0})
	sa.append(
		&g_mem.bounds,
		Line {
			Vector2{g_mem.scene_width - 30, g_mem.scene_height - 30},
			Vector2{g_mem.scene_width - 30, 30},
			1.0,
		},
	)
	sa.append(&g_mem.bounds, Line{Vector2{30, 30}, Vector2{30, g_mem.scene_height - 30}, 1.0})

	for _, idx in debug_boxes {
		width := rand.float32_range(20, 100)
		height := rand.float32_range(20, 100)

		x := rand.float32_range(width + 10, g_mem.scene_width - 10)
		y := rand.float32_range(height + 10, g_mem.scene_height - 10)
		debug_boxes[idx].shape = Rectangle{Vector2{x, y}, Vector2{width, height}, 0.0}
		debug_boxes[idx].color = Color {
			cast(u8)(rand.float32() * 255),
			cast(u8)(rand.float32() * 255),
			cast(u8)(rand.float32() * 255),
			127,
		}
	}
	mouse_box.shape = Rectangle{Vector2{}, Vector2{50, 50}, 0.0}
	mouse_box.color = RED
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

	// switch pb in ctx.playback {
	// case input.Recording:
	// 	update_gameplay(frame_input)
	// case input.Replay:
	// 	if (ctx.last_frame_id != get_frame_id(frame_input)) {
	// 		update_gameplay(frame_input)
	// 	}
	// }

	if (input.is_pressed(frame_input, .A)) {
		mouse_box.shape.rotation -= 30 * dt
	}

	if (input.is_pressed(frame_input, .D)) {
		mouse_box.shape.rotation += 30 * dt
	}

	mouse_box.shape.pos = input.mouse_position(frame_input)

	for box in &debug_boxes {
		box.shape.rotation += 10.0 * dt
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
	draw_cmds := &ctx.draw_cmds
	draw_cmds.clear(BLACK)

	// draw_cmds.draw_shape(game.paddle.shape, game.paddle.color)
	// draw_cmds.draw_shape(game.ball.shape, game.ball.color)
	draw_cmds.draw_shape(mouse_box.shape, mouse_box.color)
	lns := shape_get_rect_lines(mouse_box.shape)
	for ln in lns {
		draw_cmds.draw_shape(ln, WHITE)
	}

	for box in debug_boxes {
		lines := shape_get_rect_lines(box.shape)
		draw_cmds.draw_shape(box.shape, box.color)
		for line in lines {
			ln_copy := line
			ln_copy.thickness = 2
			draw_cmds.draw_shape(ln_copy, WHITE)

		}
		evt, is_colliding := shape_are_rects_colliding_obb_v2(mouse_box.shape, box.shape)
		if is_colliding {
		}
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

	is_locked_to_paddle := ball.state == .LockedToPaddle
	if (is_locked_to_paddle && input.is_pressed(frame_input, .SPACE)) {
		ball.state = .Free
		ball.direction = Vector2{0, -1}
	}

	if (paddle.shape.pos.x - paddle.shape.size.x / 2 < 30) {
		paddle.shape.pos.x = paddle.shape.size.x / 2 + 30
	}

	if (paddle.shape.pos.x + paddle.shape.size.x / 2 > scene_width - 30) {
		paddle.shape.pos.x = g_mem.scene_width - paddle.shape.size.x / 2 - 30
	}


	switch ball.state {
	case .LockedToPaddle:
		ball.shape.pos = paddle.shape.pos + Vector2{0, -20}
	case .Free:
		ball.direction = math.normalize(ball.direction)
		ball.shape.pos += ball.direction * ball.speed * dt


		for line in sa.slice(&g_mem.bounds) {
			evt, is_colliding := shape_check_collision(ball.shape, line)
			if is_colliding {
				if (math.abs(evt.normal.x) > 0) {
					ball.direction.x *= -1
				}
				if (math.abs(evt.normal.y) > 0) {
					ball.direction.y *= -1
				}
			}
			ball.shape.pos += evt.normal * evt.depth
		}

		evt, is_colliding := shape_check_collision(ball.shape, paddle.shape)
		if (is_colliding) {
			ball.direction.x = (ball.shape.pos.x - paddle.shape.pos.x) / (paddle.shape.size.x / 2)
			ball.direction.y *= -1
		}

		if (ball.shape.pos.y + ball.shape.radius > scene_height) {
			game_setup()
		}
	}

}


get_frame_id :: proc(frame_input: input.FrameInput) -> int {
	return frame_input.current_frame.meta.frame_id
}
