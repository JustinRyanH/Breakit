package main

import "core:fmt"
import m "core:math/linalg/hlsl"
import rl "vendor:raylib"

Paddle :: struct {
	position: m.float2,
}

Ball :: struct {
	position: m.float2,
	velocity: m.float2,
}

player1: Paddle
player2: Paddle

main :: proc() {
	fmt.println("Hellope!")

	rl.InitWindow(800, 600, "Pong")
	rl.SetTargetFPS(60)
	is_running := true

	for is_running && rl.WindowShouldClose() == false {
		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)
		rl.DrawText("Hello World!", 100, 100, 20, rl.DARKGRAY)
		rl.EndDrawing()
	}
}
