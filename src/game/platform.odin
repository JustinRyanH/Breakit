package game

import math "core:math/linalg"

//////////////////////////
///////  TYPES  //////////
//////////////////////////

Color :: distinct [4]u8

LIGHTGRAY :: Color{200, 200, 200, 255} // Light Gray
GRAY :: Color{130, 130, 130, 255} // Gray
DARKGRAY :: Color{80, 80, 80, 255} // Dark Gray
YELLOW :: Color{253, 249, 0, 255} // Yellow
GOLD :: Color{255, 203, 0, 255} // Gold
ORANGE :: Color{255, 161, 0, 255} // Orange
PINK :: Color{255, 109, 194, 255} // Pink
RED :: Color{230, 41, 55, 255} // Red
MAROON :: Color{190, 33, 55, 255} // Maroon
GREEN :: Color{0, 228, 48, 255} // Green
LIME :: Color{0, 158, 47, 255} // Lime
DARKGREEN :: Color{0, 117, 44, 255} // Dark Green
SKYBLUE :: Color{102, 191, 255, 255} // Sky Blue
BLUE :: Color{0, 121, 241, 255} // Blue
DARKBLUE :: Color{0, 82, 172, 255} // Dark Blue
PURPLE :: Color{200, 122, 255, 255} // Purple
VIOLET :: Color{135, 60, 190, 255} // Violet
DARKPURPLE :: Color{112, 31, 126, 255} // Dark Purple
BEIGE :: Color{211, 176, 131, 255} // Beige
BROWN :: Color{127, 106, 79, 255} // Brown
DARKBROWN :: Color{76, 63, 47, 255} // Dark Brown

WHITE :: Color{255, 255, 255, 255} // White
BLACK :: Color{0, 0, 0, 255} // Black
BLANK :: Color{0, 0, 0, 0} // Blank (Transparent)
MAGENTA :: Color{255, 0, 255, 255} // Magenta
RAYWHITE :: Color{245, 245, 245, 255} // My own White (raylib logo)

// Raylib Camera brought over
Camera2D :: struct {
	offset:   math.Vector2f32, // Camera offset (displacement from target)
	target:   math.Vector2f32, // Camera target (rotation and zoom origin)
	rotation: f32, // Camera rotation in degrees
	zoom:     f32, // Camera zoom (scaling), should be 1.0f by default
}

//////////////////////////
// Platform Abstraction //
//////////////////////////


PlatformCommands :: struct {
	should_close_game: proc() -> bool,
}

PlatformDrawCommands :: struct {
	begin_drawing:    proc(),
	begin_drawing_2d: proc(camera: Camera2D),
	end_drawing_2d:   proc(),
	end_drawing:      proc(),
	clear:            proc(color: Color),
	draw_text:        proc(msg: cstring, x, y: i32, font_size: i32, color: Color),
	draw_shape:       proc(shape: Shape, color: Color),
}
