package main

import "core:fmt"
import m "core:math/linalg/hlsl"
import rl "vendor:raylib"

PlayerMaxLife :: i32(5)
LinesOfBricks :: i32(5)
BricksPerLine :: i32(20)

ScreenWidth :: i32(800)
ScreenHeight :: i32(450)

game_over := false
is_running := true
pause := false
game: Game

Game :: struct {
	player:    Paddle,
	ball:      Ball,
	bricks:    [dynamic]Brick,
	brickSize: m.float2,
}


Paddle :: struct {
	position: m.float2,
	size:     m.float2,
	life:     i32,
}

Ball :: struct {
	position: m.float2,
	velocity: m.float2,
	radius:   i32,
	active:   bool,
}

Brick :: struct {
	position: m.float2,
	active:   bool,
}

InitWindow :: proc(width: i32, height: i32, window_name: string) {
	rl.InitWindow(800, 600, "Pong")
	rl.SetTargetFPS(60)
}

InitGame :: proc() {

	player := Paddle {
		position = {f32(ScreenWidth) / 2.0, f32(rl.GetScreenHeight()) * (7.0 / 8.0)},
		size = {f32(ScreenWidth) / 10.0, 20.0},
		life = PlayerMaxLife,
	}

	ball := Ball {
		position = {player.position.x, player.position.y - 20.0},
		velocity = m.float2{0, 0},
		radius = 7.0,
		active = false,
	}

	game = Game {
		player = player,
		ball = ball,
		bricks = make([dynamic]Brick, 0, LinesOfBricks * BricksPerLine),
		brickSize = m.float2{f32(rl.GetScreenWidth() / BricksPerLine), f32(40)},
	}
}

UpdateGame :: proc() {
	paddle := &game.player
	ball := &game.ball

	if (rl.IsKeyDown(rl.KeyboardKey.LEFT)) {
		paddle.position -= m.float2{5.0, 0.0}
	}
	if (rl.IsKeyDown(rl.KeyboardKey.RIGHT)) {
		paddle.position += m.float2{5.0, 0.0}
	}

	if (paddle.position.x - paddle.size.x / 2.0 <= 0.0) {
		paddle.position.x = paddle.size.x / 2.0
	}

	if (paddle.position.x + paddle.size.x / 2.0 >= f32(rl.GetScreenWidth())) {
		paddle.position.x = f32(rl.GetScreenWidth()) - paddle.size.x / 2.0
	}


	if (!ball.active) {

		new_position := paddle.position - m.float2{0.0, 20.0}
		ball.position = new_position
	}
}

UnloadGame :: proc() {}

CloseWindow :: proc() {
	rl.CloseWindow()
}

DrawGame :: proc() {
	rl.BeginDrawing()
	defer rl.EndDrawing()

	rl.ClearBackground(rl.RAYWHITE)

	player := game.player
	ball := game.ball

	rl.DrawRectangle(
		i32(player.position.x - player.size.x / 2.0),
		i32(player.position.y - player.size.y / 2.0),
		i32(player.size.x),
		i32(player.size.y),
		rl.BLACK,
	)

	rl.DrawCircleV(auto_cast ball.position, auto_cast ball.radius, rl.MAROON)
}


main :: proc() {
	InitWindow(ScreenWidth, ScreenHeight, "Pong")
	InitGame()

	for is_running && rl.WindowShouldClose() == false {
		UpdateGame()
		DrawGame()
	}

	UnloadGame()
	CloseWindow()
}
