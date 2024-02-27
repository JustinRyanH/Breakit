package game

import "core:math"
import "core:math/ease"

import "./input"

StageWin :: struct {
	flash_timer: f32,
}

stage_win_setup :: proc(stage: ^StageWin) {}

stage_win_cleanup :: proc(stage: ^StageWin) {
}

stage_win_update :: proc(stage: ^StageWin, frame: input.FrameInput) {
	dt := input.frame_query_delta(frame)
	stage.flash_timer += dt * 6
	if stage.flash_timer > math.TAU {
		stage.flash_timer = -math.TAU
	}

	if (input.was_just_released(frame, .SPACE)) {
		ring_buffer_append(&g_mem.event_queue, RestartEvent{})
	}
}

stage_win_draw :: proc(stage: StageWin) {
	draw_cmds := &ctx.draw_cmds
	draw_cmds.clear(BLACK)

	width, height := input.frame_query_dimensions(g_input)
	width_center, height_center := width * 0.5, height * 0.5

	white_zero := WHITE
	white_zero.a = 0.2

	settings := FancyTextDefaults
	settings.alignment = .Middle
	settings.color = RED

	draw_text_fancy(
		g_mem.fonts.kenney_future,
		"You Win",
		Vector2{width_center, height_center - 40},
		80,
		settings,
	)

	phase := math.sin_f32(stage.flash_timer) * 0.5 + 0.5
	settings.color = math.lerp(white_zero, WHITE, ease.circular_out(phase))

	draw_text_fancy(
		g_mem.fonts.kenney_future,
		"Press [Space] to Replay",
		Vector2{width_center, height_center + 34},
		32,
		settings,
	)
}
