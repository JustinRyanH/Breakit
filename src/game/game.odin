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
game_update :: proc(platform: PlatformCommands) -> bool {
	g_mem.some_state = 6
	return platform.should_close_game()
}

@(export)
game_draw :: proc() {
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
