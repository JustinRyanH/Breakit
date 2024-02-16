package game

import "core:fmt"
import math "core:math/linalg"

import "./input"

import mu "../microui"

GameMemory :: struct {
	last_frame_id: int,
}


ctx: ^Context
g_mem: ^GameMemory

@(export)
game_init :: proc() {
	g_mem = new(GameMemory)
}

@(export)
game_setup :: proc() {}

@(export)
game_update_context :: proc(new_ctx: ^Context) {
	ctx = new_ctx
}

@(export)
game_update :: proc() -> bool {
	return ctx.cmds.should_close_game()
}

@(export)
game_draw :: proc() {
	draw_cmds := &ctx.draw_cmds
	draw_cmds.clear(BLACK)
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
