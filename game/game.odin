package game

import "core:fmt"
import rl "vendor:raylib"

GameMemory :: struct {
	some_state: int,
}


g_mem: ^GameMemory

@(export)
game_init :: proc() {
	g_mem = new(GameMemory)

	rl.InitWindow(800, 600, "Breakit")
	rl.SetTargetFPS(30.0)
}

@(export)
game_update :: proc() -> bool {
	g_mem.some_state = 0
	fmt.println("some_state", g_mem.some_state)
	return rl.WindowShouldClose()
}

@(export)
game_draw :: proc() {
	rl.BeginDrawing()
	defer rl.EndDrawing()

	rl.ClearBackground(rl.RAYWHITE)
	rl.DrawText("Breakit", 200, 200, 20, rl.DARKGRAY)
}

@(export)
game_shutdown :: proc() {
	rl.CloseWindow()
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
