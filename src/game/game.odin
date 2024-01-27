package game

import "core:fmt"
import math "core:math/linalg"
import rl "vendor:raylib"

GameMemory :: struct {
	ctx:           ^Context,
	ball_position: math.Vector2f32,
}


g_mem: ^GameMemory

@(export)
game_init :: proc() {
	g_mem = new(GameMemory)
	g_mem.ball_position = {400, 400}
}

@(export)
game_update :: proc(ctx: ^Context) -> bool {
	g_mem.ctx = ctx

	input := ctx.input
	cmds := g_mem.ctx.cmds
	dt := get_frame_time(input)


	if is_right_arrow_down(input) {
		g_mem.ball_position.x += 100 * dt
	}
	if is_left_arrow_down(input) {
		g_mem.ball_position.x -= 100 * dt
	}

	return cmds.should_close_game()
}

@(export)
game_draw :: proc(platform_draw: ^PlatformDrawCommands) {
	game := g_mem
	platform_draw.begin_drawing()
	defer platform_draw.end_drawing()
	platform_draw.clear(BLACK)

	rect := Rectangle{50, 50, 100, 100}
	platform_draw.draw_rect(rect, {25, 25}, 0, BLUE)
	platform_draw.draw_circle(game.ball_position, 30, GREEN)


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
