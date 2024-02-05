package input

import "core:fmt"

import game "../game"
import rl_platform "../raylib_platform"
import rl "vendor:raylib"

main :: proc() {
	rl.InitWindow(800, 450, "Input Debugger")
	rl.SetTargetFPS(30.0)
	defer rl.CloseWindow()

	panel_rect := rl.Rectangle{0, 0, 400, 450}
	panel_rect.x = 800 - panel_rect.width
	panel_content_rect := rl.Rectangle{20, 40, 1_500, 10_000}
	panel_view := rl.Rectangle{}
	panel_scroll := rl.Vector2{99, -20}

	frame := game.FrameInput{}
	for {
		frame = rl_platform.update_frame(frame)
		if rl.WindowShouldClose() {
			break
		}

		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground(rl.RAYWHITE)

		rl.DrawText(fmt.ctprintf("P(%v)", panel_scroll), 10, 10, 20, rl.MAROON)

		grid_rect := rl.Rectangle {
			panel_rect.x + panel_scroll.x,
			panel_rect.y + panel_scroll.y,
			panel_content_rect.width + 12,
			panel_content_rect.height + 12,
		}
		rl.GuiScrollPanel(panel_rect, nil, panel_content_rect, &panel_scroll, &panel_view)
		{
			rl.BeginScissorMode(
				cast(i32)(panel_rect.x),
				cast(i32)(panel_rect.y),
				cast(i32)(panel_rect.width - 12),
				cast(i32)(panel_rect.height - 12),
			)
			defer rl.EndScissorMode()
			rl.GuiGrid(grid_rect, nil, 16, 3, nil)
			text := fmt.ctprintf("Frame: %v", frame.current_frame)
			text_width := cast(f32)(rl.MeasureText(text, 16)) + 20
			if text_width > panel_content_rect.width {
				panel_content_rect.width = text_width
			}
			rl.DrawText(
				text,
				cast(i32)(grid_rect.x + 5),
				cast(i32)(grid_rect.y + 20),
				12,
				rl.MAROON,
			)
		}
	}
}
