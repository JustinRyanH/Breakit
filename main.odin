package main

import "core:fmt"
import rl "vendor:raylib"


main :: proc() {
	rl.InitWindow(800, 450, "Odin Snake")
	rl.SetTargetFPS(60)


	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		defer rl.EndDrawing()

		rl.ClearBackground(rl.RAYWHITE)
		rl.DrawText("Congrats you created your first window", 190, 200, 20, rl.LIGHTGRAY)
	}
}
