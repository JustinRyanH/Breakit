package main

import "core:fmt"
import m "core:math/linalg/hlsl"
import rl "vendor:raylib"

PlayerMaxLife :: int(5)
LinesOfBricks :: int(5)
BrikesPerLine :: int(20)

ScreenWidth :: i32(800)
ScreenHeight :: i32(450)

game_over := false
is_running := true
pause := false


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

InitGame :: proc() {
	rl.InitWindow(800, 600, "Pong")
	rl.SetTargetFPS(60)
}

UpdateGame :: proc() {}

DrawGame :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.RAYWHITE)
	rl.DrawText("Hello World!", 100, 100, 20, rl.DARKGRAY)
	rl.EndDrawing()
}


main :: proc() {
	InitGame()

	for is_running && rl.WindowShouldClose() == false {
		DrawGame()
	}
}
