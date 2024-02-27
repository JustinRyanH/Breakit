package game

import "core:fmt"
import "core:math"
import "core:math/ease"

import "./input"

StageLose :: struct {
	flash_timer: f32,
}

FancyTextDefaults :: FancyText{WHITE, .Left, 0}

stage_lose_setup :: proc(stage: ^StageLose) {}

stage_lose_cleanup :: proc(stage: ^StageLose) {}

stage_lose_update :: proc(stage: ^StageLose, frame: input.FrameInput) {
	dt := input.frame_query_delta(frame)
	stage.flash_timer += dt * 2
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


draw_text_fancy :: proc(
	font: Font,
	txt: cstring,
	pos: Vector2,
	size: f32,
	settings := FancyTextDefaults,
) {
	text_cmds := &ctx.draw_cmds.text
	width, height := input.frame_query_dimensions(g_input)


	switch settings.alignment {
	case .Left:
		dims := text_cmds.measure_text(g_mem.fonts.kenney_future, txt, size, settings.spacing)

		text_cmds.draw(
			font,
			txt,
			pos - Vector2{0, dims.y * 0.5},
			size,
			settings.spacing,
			settings.color,
		)
	case .Right:
		dims := text_cmds.measure_text(g_mem.fonts.kenney_future, txt, size, settings.spacing)

		text_cmds.draw(
			font,
			txt,
			pos - Vector2{dims.x, dims.y * 0.5},
			size,
			settings.spacing,
			settings.color,
		)
	case .Middle:
		dims := text_cmds.measure_text(g_mem.fonts.kenney_future, txt, size, settings.spacing)

		text_cmds.draw(font, txt, pos - dims * 0.5, size, settings.spacing, settings.color)
	}

}

FancyText :: struct {
	color:     Color,
	alignment: TextAlignment,
	spacing:   f32,
}

TextAlignment :: enum {
	Left,
	Middle,
	Right,
}
