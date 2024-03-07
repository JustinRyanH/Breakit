package platform_raylib

import "core:fmt"
import math "core:math/linalg"
import "core:strings"

import mu "../microui"
import rl "vendor:raylib"

import "../game"
import "../game/input"


// This doesn't need to be a data pool. I can just
// generate a 64bit hash from the string and store
// that. I only care about DataPool style API from
// within the GAME
PlatformStorage :: struct {
	fonts:  map[game.FontHandle]PlatformFont,
	images: map[game.ImageHandle]PlatformImage,
}

platform_storage: PlatformStorage

PlatformFont :: struct {
	game_font: game.Font,
	rl_font:   rl.Font,
}

PlatformImage :: struct {
	game_img: game.Image,
	rl_img:   rl.Texture,
}

RlToGameKeyMap :: struct {
	rl_key:   rl.KeyboardKey,
	game_key: input.KeyboardKey,
}

RlToGameMouseMap :: struct {
	rl_btn:   rl.MouseButton,
	game_btn: input.MouseButton,
}

keys_to_check :: [?]RlToGameKeyMap {
	{.COMMA, .COMMA},
	{.MINUS, .MINUS},
	{.PERIOD, .PERIOD},
	{.SLASH, .SLASH},
	{.ZERO, .ZERO},
	{.ONE, .ONE},
	{.TWO, .TWO},
	{.THREE, .THREE},
	{.FOUR, .FOUR},
	{.FIVE, .FIVE},
	{.SIX, .SIX},
	{.SEVEN, .SEVEN},
	{.EIGHT, .EIGHT},
	{.NINE, .NINE},
	{.SEMICOLON, .SEMICOLON},
	{.EQUAL, .EQUAL},
	{.A, .A},
	{.B, .B},
	{.C, .C},
	{.D, .D},
	{.E, .E},
	{.F, .F},
	{.G, .G},
	{.H, .H},
	{.I, .I},
	{.J, .J},
	{.K, .K},
	{.L, .L},
	{.M, .M},
	{.N, .N},
	{.O, .O},
	{.P, .P},
	{.Q, .Q},
	{.R, .R},
	{.S, .S},
	{.T, .T},
	{.U, .U},
	{.V, .V},
	{.W, .W},
	{.X, .X},
	{.Y, .Y},
	{.Z, .Z},
	{.LEFT_BRACKET, .LEFT_BRACKET},
	{.BACKSLASH, .BACKSLASH},
	{.RIGHT_BRACKET, .RIGHT_BRACKET},
	{.GRAVE, .GRAVE},
	{.SPACE, .SPACE},
	{.ESCAPE, .ESCAPE},
	{.ENTER, .ENTER},
	{.TAB, .TAB},
	{.BACKSPACE, .BACKSPACE},
	{.INSERT, .INSERT},
	{.DELETE, .DELETE},
	{.RIGHT, .RIGHT},
	{.LEFT, .LEFT},
	{.DOWN, .DOWN},
	{.UP, .UP},
	{.PAGE_UP, .PAGE_UP},
	{.PAGE_DOWN, .PAGE_DOWN},
	{.HOME, .HOME},
	{.END, .END},
	{.CAPS_LOCK, .CAPS_LOCK},
	{.SCROLL_LOCK, .SCROLL_LOCK},
	{.NUM_LOCK, .NUM_LOCK},
	{.PRINT_SCREEN, .PRINT_SCREEN},
	{.PAUSE, .PAUSE},
	{.F1, .F1},
	{.F2, .F2},
	{.F3, .F3},
	{.F4, .F4},
	{.F5, .F5},
	{.F6, .F6},
	{.F7, .F7},
	{.F8, .F8},
	{.F9, .F9},
	{.F10, .F10},
	{.F11, .F11},
	{.F12, .F12},
	{.LEFT_SHIFT, .LEFT_SHIFT},
	{.LEFT_CONTROL, .LEFT_CONTROL},
	{.LEFT_ALT, .LEFT_ALT},
	{.LEFT_SUPER, .LEFT_SUPER},
	{.RIGHT_SHIFT, .RIGHT_SHIFT},
	{.RIGHT_CONTROL, .RIGHT_CONTROL},
	{.RIGHT_ALT, .RIGHT_ALT},
	{.RIGHT_SUPER, .RIGHT_SUPER},
	{.KB_MENU, .KB_MENU},
	{.KP_0, .KP_0},
	{.KP_1, .KP_1},
	{.KP_2, .KP_2},
	{.KP_3, .KP_3},
	{.KP_4, .KP_4},
	{.KP_5, .KP_5},
	{.KP_6, .KP_6},
	{.KP_7, .KP_7},
	{.KP_8, .KP_8},
	{.KP_9, .KP_9},
	{.KP_DECIMAL, .KP_DECIMAL},
	{.KP_DIVIDE, .KP_DIVIDE},
	{.KP_MULTIPLY, .KP_MULTIPLY},
	{.KP_SUBTRACT, .KP_SUBTRACT},
	{.KP_ADD, .KP_ADD},
	{.KP_ENTER, .KP_ENTER},
	{.KP_EQUAL, .KP_EQUAL},
	{.BACK, .BACK},
	{.MENU, .MENU},
	{.VOLUME_UP, .VOLUME_UP},
	{.VOLUME_DOWN, .VOLUME_DOWN},
	// {.APOSTROPH, .APOSTROPH},
}

mouse_btn_to_check :: [?]RlToGameMouseMap {
	{.LEFT, .LEFT},
	{.RIGHT, .RIGHT},
	{.MIDDLE, .MIDDLE},
	{.SIDE, .SIDE},
	{.EXTRA, .EXTRA},
	{.FORWARD, .FORWARD},
	{.BACK, .BACK},
}

new_context :: proc() -> ^game.Context {
	ctx := new(game.Context)
	ctx.playback = input.Recording{0}

	mu.init(&ctx.mui)

	setup_raylib_platform(&ctx.cmds)
	setup_raylib_draw_cmds(&ctx.draw_cmds)
	return ctx
}

deinit_game_context :: proc(ctx: ^game.Context) {
	free(ctx)
}

new_platform_storage :: proc() {
	platform_storage.fonts = make(map[game.FontHandle]PlatformFont)
	platform_storage.images = make(map[game.ImageHandle]PlatformImage)
}

free_platform_storage :: proc() {
	delete(platform_storage.fonts)
	delete(platform_storage.images)
}


// Returns the current user input, frame id is zero
get_current_user_input :: proc() -> (new_input: input.UserInput) {
	new_input.meta = input.FrameMeta {
		0,
		rl.GetFrameTime(),
		cast(f32)rl.GetScreenWidth(),
		cast(f32)rl.GetScreenHeight(),
	}


	key_pressed := rl.GetKeyPressed()
	for key in keys_to_check {
		if rl.IsKeyDown(key.rl_key) {
			new_input.keyboard += {key.game_key}
		}
	}

	new_input.mouse.pos = cast(math.Vector2f32)(rl.GetMousePosition())
	for btn in mouse_btn_to_check {
		if rl.IsMouseButtonDown(btn.rl_btn) {
			new_input.mouse.buttons += {btn.game_btn}
		}
	}

	return new_input
}

///// Private

@(private)
setup_raylib_platform :: proc(cmds: ^game.PlatformCommands) {
	cmds.should_close_game = cast(proc() -> bool)(rl.WindowShouldClose)
}

@(private)
setup_raylib_draw_cmds :: proc(draw: ^game.PlatformDrawCommands) {
	draw.begin_drawing = cast(proc())(rl.BeginDrawing)
	draw.draw_mui = render_mui
	draw.end_drawing = cast(proc())(rl.EndDrawing)
	draw.clear = raylib_clear_background
	draw.draw_text = raylib_draw_text
	draw.draw_shape = raylib_draw_shape
	draw.draw_grid = raylib_draw_grid

	draw.load_img = raylib_load_img
	draw.unload_img = raylib_unload_img
	draw.draw_img = raylib_draw_img

	draw.text.load_font = raylib_load_font
	draw.text.unload_font = raylib_unload_font
	draw.text.measure_text = raylib_measure_text
	draw.text.draw = raylib_draw_text_ex

	draw.camera.begin_drawing_2d = raylib_begin_drawing_2d
	draw.camera.end_drawing_2d = raylib_end_drawing_2d
	draw.camera.screen_to_world_2d = raylib_camera_screen_to_world_2d
	draw.camera.world_to_sreen_2d = raylib_camera_world_to_sreen_2d
}

@(private)
raylib_clear_background :: proc(color: game.Color) {
	rl.ClearBackground(game_color_to_raylib_color(color))
}

@(private)
raylib_draw_text :: proc(msg: cstring, x, y: i32, font_size: i32, color: game.Color) {
	rl.DrawText(msg, x, y, font_size, game_color_to_raylib_color(color))
}

// game_color_to_raylib_color
@(private)
raylib_draw_shape :: proc(shape: game.Shape, color: game.Color) {
	switch s in shape {
	case game.Circle:
		rl.DrawCircleV(s.pos, s.radius, game_color_to_raylib_color(color))
	case game.Rectangle:
		origin := s.size * 0.5
		rl_rect: rl.Rectangle = {s.pos.x, s.pos.y, s.size.x, s.size.y}
		rl.DrawRectanglePro(rl_rect, origin, s.rotation, game_color_to_raylib_color(color))
	case game.Line:
		rl.DrawLineEx(s.start, s.end, s.thickness, game_color_to_raylib_color(color))
		rl.DrawCircleV(s.start, s.thickness / 2, game_color_to_raylib_color(color))
		rl.DrawCircleV(s.end, s.thickness / 2, game_color_to_raylib_color(color))
	}
}

raylib_begin_drawing_2d :: proc(camera: game.Camera2D) {
	rl.BeginMode2D(cast(rl.Camera2D)(camera))
}

raylib_end_drawing_2d :: proc() {
	rl.EndMode2D()
}

raylib_camera_screen_to_world_2d :: proc(
	camera: game.Camera2D,
	screen_pos: game.Vector2,
) -> game.Vector2 {
	return rl.GetScreenToWorld2D(screen_pos, cast(rl.Camera2D)camera)
}
raylib_camera_world_to_sreen_2d :: proc(
	camera: game.Camera2D,
	world_pos: game.Vector2,
) -> game.Vector2 {
	return rl.GetWorldToScreen2D(world_pos, cast(rl.Camera2D)camera)
}

raylib_load_font :: proc(path: cstring) -> (font: game.Font) {
	handle := transmute(game.FontHandle)game.generate_u64_from_cstring(path)

	if !(handle in platform_storage.fonts) {
		rl_font := rl.LoadFontEx(path, 96, nil, 0)
		font.handle = handle
		font.name = strings.clone_from_cstring(path)

		pff := PlatformFont{}
		pff.rl_font = rl_font
		pff.game_font = font
		platform_storage.fonts[handle] = pff
	}
	return platform_storage.fonts[handle].game_font
}

raylib_unload_font :: proc(font: game.Font) {
	f, exists := platform_storage.fonts[font.handle]
	if exists {
		delete(f.game_font.name)
		rl.UnloadFont(f.rl_font)
	}
	delete_key(&platform_storage.fonts, font.handle)
}

raylib_draw_text_ex :: proc(
	font: game.Font,
	text: cstring,
	pos: math.Vector2f32,
	size: f32,
	spacing: f32,
	color: game.Color,
) -> game.PlatformCommandError {
	if font.handle in platform_storage.fonts {
		f := platform_storage.fonts[font.handle]
		rl.DrawTextEx(f.rl_font, text, pos, size, spacing, game_color_to_raylib_color(color))
		return .NoError
	}
	return .FontNotFound
}

raylib_draw_grid :: proc(slices: int, spacing: f32, offset: math.Vector2f32) {
	using rl
	rlPushMatrix()
	defer rlPopMatrix()

	rlTranslatef(offset.x, offset.y, 0)
	rlRotatef(90, 1, 0, 0)
	DrawGrid(cast(i32)slices, spacing)
}

raylib_load_img :: proc(path: cstring) -> (img: game.Image, err: game.PlatformCommandError) {
	handle := transmute(game.ImageHandle)game.generate_u64_from_cstring(path)
	if !(handle in platform_storage.images) {
		rl_img := rl.LoadTexture(path)
		img.handle = handle
		img.path = strings.clone_from_cstring(path)
		platform_storage.images[handle] = PlatformImage{img, rl_img}
		return
	}
	img = platform_storage.images[handle].game_img
	return
}

raylib_unload_img :: proc(img: game.ImageHandle) {
	f, exists := platform_storage.images[img]
	if exists {
		delete(f.game_img.path)
		rl.UnloadTexture(f.rl_img)
	}
	delete_key(&platform_storage.images, img)
}

raylib_draw_img :: proc(img: game.AtlasImage, color: game.Color) -> game.PlatformCommandError {
	if img.image in platform_storage.images {
		f := platform_storage.images[img.image]

		r := rl.Rectangle{img.pos.x, img.pos.y, img.size.x, img.size.y}
		rl.DrawTexturePro(
			f.rl_img,
			rl.Rectangle{img.src.pos.x, img.src.pos.y, img.src.size.x, img.src.size.y},
			r,
			img.origin,
			img.rotation,
			game_color_to_raylib_color(color),
		)
		return .NoError
	}
	return .ImageNotFound
}

raylib_measure_text :: proc(
	font: game.Font,
	text: cstring,
	size: f32,
	spacing: f32,
) -> math.Vector2f32 {
	f, exist := platform_storage.fonts[font.handle]
	if !exist {
		return math.Vector2f32{}
	}
	return rl.MeasureTextEx(f.rl_font, text, size, spacing)
}

// Clamps the color between 0 and 1. (Sorry no HDR colors for Direct Raylib API)
game_color_to_raylib_color :: proc "contextless" (color: game.Color) -> rl.Color {
	out := rl.Color{}
	out.r = cast(u8)(math.clamp(color.r, 0, 1) * 255)
	out.b = cast(u8)(math.clamp(color.b, 0, 1) * 255)
	out.g = cast(u8)(math.clamp(color.g, 0, 1) * 255)
	out.a = cast(u8)(math.clamp(color.a, 0, 1) * 255)
	return out
}
