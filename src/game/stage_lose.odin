package game

import "core:fmt"

import "./input"

StageLose :: struct {}

stage_lose_setup :: proc(stage: ^StageLose) {}

stage_lose_cleanup :: proc(stage: ^StageLose) {}

stage_lose_update :: proc(stage: ^StageLose, frame: input.FrameInput) {}

stage_lose_render :: proc(stage: StageLose) {
	draw_cmds := &ctx.draw_cmds
	draw_cmds.clear(BLACK)

	width, height := input.frame_query_dimensions(g_input)

	draw_cmds.text.draw(
		g_mem.fonts.kenney_block,
		fmt.ctprintf("Entities Len: %v", data_pool_len(&g_mem.entities)),
		Vector2{10, 50},
		24,
		0,
		RED,
	)
}
