package game

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

draw_text_fancy :: proc(
	font: Font,
	txt: cstring,
	pos: Vector2,
	size: f32,
	settings := FancyTextDefaults,
) {
	text_cmds := &ctx.draw_cmds.text

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
