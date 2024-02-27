package game

import "core:fmt"
import "core:math"
import "core:math/ease"

import "./input"

StageLose :: struct {
	flash_timer: f32,
}

FancyTextDefaults :: FancyText{WHITE, .Left, 0}

stage_lose_setup :: proc(stage: ^StageLose) {
	stage.flash_timer = -math.TAU
}

stage_lose_cleanup :: proc(stage: ^StageLose) {}

stage_lose_update :: proc(stage: ^StageLose, frame: input.FrameInput) {
	dt := input.frame_query_delta(frame)
	stage.flash_timer += dt * 4
	if stage.flash_timer > math.TAU {
		stage.flash_timer = -math.TAU
	}


	if (input.was_just_released(frame, .SPACE)) {
		ring_buffer_append(&g_mem.event_queue, RestartEvent{})
	}
}

stage_lose_render :: proc(stage: StageLose) {
	draw_cmds := &ctx.draw_cmds
	draw_cmds.clear(BLACK)

	width, height := input.frame_query_dimensions(g_input)
	width_center, height_center := width * 0.5, height * 0.5

	red_zero := RED
	red_zero.a = 0.2

	settings := FancyTextDefaults
	settings.alignment = .Middle
	settings.color = RED

	draw_text_fancy(
		g_mem.fonts.kenney_future,
		"Game Over",
		Vector2{width_center, height_center - 40},
		80,
		settings,
	)

	phase := math.sin_f32(stage.flash_timer) * 0.5 + 0.5
	settings.color = math.lerp(red_zero, RED, ease.circular_out(phase))

	draw_text_fancy(
		g_mem.fonts.kenney_future,
		"Press [Space] to restart",
		Vector2{width_center, height_center + 34},
		32,
		settings,
	)
}
