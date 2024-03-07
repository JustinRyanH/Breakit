package game

import mu "../microui"
import math "core:math/linalg"

//////////////////////////
///////  TYPES  //////////
//////////////////////////

Color :: distinct [4]f32

LIGHTGRAY :: Color{200 / 255.0, 200 / 255.0, 200 / 255.0, 255} // Light Gray
GRAY :: Color{130 / 255.0, 130 / 255.0, 130 / 255.0, 255 / 255.0} // Gray
DARKGRAY :: Color{80 / 255.0, 80 / 255.0, 80 / 255.0, 255 / 255.0} // Dark Gray
YELLOW :: Color{253 / 255.0, 249 / 255.0, 0 / 255.0, 255 / 255.0} // Yellow
GOLD :: Color{255 / 255.0, 203 / 255.0, 0 / 255.0, 255 / 255.0} // Gold
ORANGE :: Color{255 / 255.0, 161 / 255.0, 0 / 255.0, 255 / 255.0} // Orange
PINK :: Color{255 / 255.0, 109 / 255.0, 194 / 255.0, 255 / 255.0} // Pink
RED :: Color{230 / 255.0, 41 / 255.0, 55 / 255.0, 255 / 255.0} // Red
MAROON :: Color{190 / 255.0, 33 / 255.0, 55 / 255.0, 255 / 255.0} // Maroon
GREEN :: Color{0 / 255.0, 228 / 255.0, 48 / 255.0, 255 / 255.0} // Green
LIME :: Color{0 / 255.0, 158 / 255.0, 47 / 255.0, 255 / 255.0} // Lime
DARKGREEN :: Color{0 / 255.0, 117 / 255.0, 44 / 255.0, 255 / 255.0} // Dark Green
SKYBLUE :: Color{102 / 255.0, 191 / 255.0, 255 / 255.0, 255 / 255.0} // Sky Blue
BLUE :: Color{0 / 255.0, 121 / 255.0, 241 / 255.0, 255 / 255.0} // Blue
DARKBLUE :: Color{0 / 255.0, 82 / 255.0, 172 / 255.0, 255 / 255.0} // Dark Blue
PURPLE :: Color{200 / 255.0, 122 / 255.0, 255 / 255.0, 255 / 255.0} // Purple
VIOLET :: Color{135 / 255.0, 60 / 255.0, 190 / 255.0, 255 / 255.0} // Violet
DARKPURPLE :: Color{112 / 255.0, 31 / 255.0, 126 / 255.0, 255 / 255.0} // Dark Purple
BEIGE :: Color{211 / 255.0, 176 / 255.0, 131 / 255.0, 255 / 255.0} // Beige
BROWN :: Color{127 / 255.0, 106 / 255.0, 79 / 255.0, 255 / 255.0} // Brown
DARKBROWN :: Color{76 / 255.0, 63 / 255.0, 47 / 255.0, 255 / 255.0} // Dark Brown

WHITE :: Color{255 / 255.0, 255 / 255.0, 255 / 255.0, 255 / 255.0} // White
BLACK :: Color{0, 0, 0, 1} // Black
BLANK :: Color{0 / 255.0, 0 / 255.0, 0 / 255.0, 0 / 255.0} // Blank (Transparent)
MAGENTA :: Color{255 / 255.0, 0 / 255.0, 255 / 255.0, 255 / 255.0} // Magenta
RAYWHITE :: Color{245 / 255.0, 245 / 255.0, 245 / 255.0, 255 / 255.0} // My own White (raylib logo)

// Raylib Camera brought over
Camera2D :: struct {
	offset:   math.Vector2f32, // Camera offset (displacement from target)
	target:   math.Vector2f32, // Camera target (rotation and zoom origin)
	rotation: f32, // Camera rotation in degrees
	zoom:     f32, // Camera zoom (scaling), should be 1.0f by default
}

FontHandle :: distinct Handle
Font :: struct {
	handle: FontHandle,
	name:   string,
}

ImageHandle :: distinct Handle
Image :: struct {
	handle: ImageHandle,
	path:   string,
}

PlatformCommandError :: enum {
	NoError,
	FontNotFound,
	ImageNotFound,
}

AtlasImage :: struct {
	image:    ImageHandle,
	pos:      Vector2,
	size:     Vector2,
	origin:   Vector2,
	src:      Rectangle,
	rotation: f32,
}


//////////////////////////
// Platform Abstraction //
//////////////////////////

TextCommands :: struct {
	load_font:    proc(path: cstring) -> Font,
	unload_font:  proc(font: Font),
	measure_text: proc(font: Font, text: cstring, font_size: f32, spacing: f32) -> math.Vector2f32,
	draw:         proc(
		font: Font,
		text: cstring,
		pos: math.Vector2f32,
		size: f32,
		spacing: f32,
		color: Color,
	) -> PlatformCommandError,
}

CameraCommands :: struct {
	begin_drawing_2d:   proc(camera: Camera2D),
	end_drawing_2d:     proc(),
	screen_to_world_2d: proc(camera: Camera2D, screen_pos: Vector2) -> Vector2,
	world_to_sreen_2d:  proc(camera: Camera2D, world_pos: Vector2) -> Vector2,
}


PlatformCommands :: struct {
	should_close_game: proc() -> bool,
}

PlatformDrawCommands :: struct {
	begin_drawing: proc(),
	draw_mui:      proc(mui: ^mu.Context),
	end_drawing:   proc(),
	clear:         proc(color: Color),
	draw_text:     proc(msg: cstring, x, y: i32, font_size: i32, color: Color),
	draw_shape:    proc(shape: Shape, color: Color),
	load_img:      proc(file: cstring) -> (Image, PlatformCommandError),
	unload_img:    proc(img: ImageHandle),
	draw_img:      proc(image: AtlasImage, color: Color) -> PlatformCommandError,
	draw_grid:     proc(slices: int, spacing: f32, offset: Vector2),
	text:          TextCommands,
	camera:        CameraCommands,
}
