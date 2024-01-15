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
	ball := Ball{}

	player := Paddle {
		position = {f32(ScreenWidth) / 2.0, f32(ScreenHeight) * 7.0 / 8.0},
		size = {f32(ScreenWidth) / 10.0, 20.0},
		life = PlayerMaxLife,
	}

	game = Game {
		player = player,
		ball = ball,
		bricks = make([dynamic]Brick, 0, LinesOfBricks * BricksPerLine),
		brickSize = m.float2{f32(rl.GetScreenWidth() / BricksPerLine), f32(40)},
	}
}

UpdateGame :: proc() {}

UnloadGame :: proc() {}

CloseWindow :: proc() {
	rl.CloseWindow()
}

DrawGame :: proc() {
	rl.BeginDrawing()
	defer rl.EndDrawing()

	rl.ClearBackground(rl.RAYWHITE)

  player := game.player
	rl.DrawRectangle(
		i32(player.position.x - player.size.x / 2.0),
		i32(player.position.y - player.size.y / 2.0),
		i32(player.size.x),
		i32(player.size.y),
		rl.BLACK
	)
}


main :: proc() {
	InitWindow(ScreenWidth, ScreenHeight, "Pong")
	InitGame()

	for is_running && rl.WindowShouldClose() == false {
		DrawGame()
	}

	UnloadGame()
	CloseWindow()
}
