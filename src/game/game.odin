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
}

@(export)
game_update :: proc(platform: ^PlatformCommands) -> bool {
	g_mem.some_state = 6
	return platform.should_close_game()
}

@(export)
game_draw :: proc(platform_draw: ^PlatformDrawCommands) {
	{
		platform_draw.begin_drawing()
		defer platform_draw.end_drawing()
		platform_draw.clear(BLACK)

		rect := Rectangle{50, 50, 100, 100}
		platform_draw.draw_rect(rect, {25, 25}, 0, BLUE)


		platform_draw.draw_text("Breakit", 10, 56 / 3, 56, RED)
	}
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
