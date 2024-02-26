package game

import "core:fmt"

import "./input"

StageLose :: struct {}


FancyTextDefaults :: FancyText{WHITE, .Left, 0}

stage_lose_setup :: proc(stage: ^StageLose) {}

stage_lose_cleanup :: proc(stage: ^StageLose) {}

stage_lose_update :: proc(stage: ^StageLose, frame: input.FrameInput) {}

stage_lose_render :: proc(stage: StageLose) {
	draw_cmds := &ctx.draw_cmds
	draw_cmds.clear(BLACK)

	width, height := input.frame_query_dimensions(g_input)

	settings := FancyTextDefaults
	settings.alignment = .Middle
	draw_text_fancy(g_mem.fonts.kenney_future, "Restart", Vector2{width * 0.5, height * 0.5}, 60, settings)
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

		text_cmds.draw(font, txt, pos - Vector2{ 0, dims.y * 0.5 }, size, settings.spacing, settings.color)
	case .Right:
		dims := text_cmds.measure_text(g_mem.fonts.kenney_future, txt, size, settings.spacing)

		text_cmds.draw(font, txt, pos - Vector2{ dims.x, dims.y * 0.5 }, size, settings.spacing, settings.color)
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
