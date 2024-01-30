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
  camera: Camera2D,

	// TODO: Remove these
	mouse_rect:     Rectangle,
	static_circle:  Circle,
	static_rect:    Rectangle,
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

	g_mem.mouse_rect = Rectangle{Vec2{0, 0}, Vec2{55, 100}, 0}
	g_mem.static_circle = Circle {
		Vec2{meta.screen_width / 2.0, meta.screen_height / 2.0} + Vec2{150, 100},
		20,
	}
	g_mem.static_rect = Rectangle {
		Vec2{meta.screen_width / 2.0, meta.screen_height / 2.0} + Vec2{-150, 100},
		Vec2{100, 100},
    0.0
	}
}

@(export)
game_update :: proc(ctx: ^Context) -> bool {
	g_mem.ctx = ctx
	game := g_mem



	input := ctx.frame
	cmds := game.ctx.cmds
	dt := frame_query_delta(input)

	screen_width := ctx.frame.current_frame.meta.screen_width
  screen_height := ctx.frame.current_frame.meta.screen_height
	paddle := &game.paddle

  game.camera.target = Vec2{
    0,
    0,
  }
  game.camera.offset = Vec2 {
    screen_width / 2,
    screen_height / 2,
  }

  game.camera.zoom = -2.5
  game.camera.rotation = 90

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

  game.mouse_rect.pos = input_mouse_position(input)

	return cmds.should_close_game()
}

@(export)
game_draw :: proc(platform_draw: ^PlatformDrawCommands) {
	game := g_mem
	platform_draw.begin_drawing()
	defer platform_draw.end_drawing()
	platform_draw.clear(BLACK)

  {
    platform_draw.begin_drawing_2d(game.camera)
    defer platform_draw.end_drawing_2d()

    platform_draw.draw_shape(Line{ Vec2 { -1000, 0 }, Vec2 { 1000, 0 }, 1 }, Color{ 255, 255, 255, 30 })
    platform_draw.draw_shape(Line{ Vec2 { 0, -1000 }, Vec2 { 0, 1000 }, 1 }, Color{ 255, 255, 255, 30 })

  }

	// platform_draw.draw_shape(game.paddle, BLUE)
	// platform_draw.draw_shape(game.ball, RED)

  //static_rect_color := GREEN if shape_are_rects_colliding(game.static_rect, game.mouse_rect) else RED
  //static_circle_color := GREEN if shape_is_circle_colliding_rectangle(game.static_circle, game.mouse_rect) else RED

  //platform_draw.draw_shape(game.mouse_rect, WHITE)
  //platform_draw.draw_shape(game.static_circle, static_circle_color)
  //platform_draw.draw_shape(game.static_rect, static_rect_color)

  //platform_draw.draw_shape(Line{ game.mouse_rect.pos, game.static_circle.pos, 2.0 }, ORANGE)

  //origin := Vec2 { 400, 400 }
  //d := Vec2 { 20, -500 }
  //platform_draw.draw_shape(Line{ origin, d, 3 }, RED)

  //lines := shape_get_rect_lines_t(game.mouse_rect)
  //for i := 0; i < len(lines); i += 1 {
  //    line := lines[i]
  //    line.thickness = 2.0
  //    platform_draw.draw_shape(line, SKYBLUE)
  //}


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
