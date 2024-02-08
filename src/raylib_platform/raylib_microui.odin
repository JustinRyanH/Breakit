package platform_raylib

import "core:strings"
import "core:unicode/utf8"

import mu "vendor:microui"
import rl "vendor:raylib"

pixels: [][4]u8
atlas: rl.Texture

RlToMuMouseMap :: struct {
	rl_button: rl.MouseButton,
	mu_button: mu.Mouse,
}

RlToMuKeyMap :: struct {
	rl_key: rl.KeyboardKey,
	mu_key: mu.Key,
}

create_mu_framebuffer :: proc(ctx: ^mu.Context) {
	pixels = make([][4]u8, mu.DEFAULT_ATLAS_WIDTH * mu.DEFAULT_ATLAS_HEIGHT)
	for alpha, i in mu.default_atlas_alpha {
		pixels[i].rgb = 0xff
		pixels[i].a = alpha
	}
	atlas_image := rl.Image {
		data    = raw_data(pixels),
		width   = mu.DEFAULT_ATLAS_WIDTH,
		height  = mu.DEFAULT_ATLAS_HEIGHT,
		mipmaps = 1,
		format  = .UNCOMPRESSED_R8G8B8A8,
	}
	atlas = rl.LoadTextureFromImage(atlas_image)
}

destroy_mu_framebuffer :: proc() {
	rl.UnloadTexture(atlas)
	delete(pixels)
}

load_input :: proc(ctx: ^mu.Context) {
	@(static)
	test_input_buffer: [512]byte

	text_input_offset := 0

	for text_input_offset < len(test_input_buffer) {
		ch := rl.GetCharPressed()
		if ch == 0 {
			break
		}
		bytes, width := utf8.encode_rune(ch)
		copy(test_input_buffer[text_input_offset:], bytes[:width])
		text_input_offset += width
	}

	mu.input_text(ctx, string(test_input_buffer[:text_input_offset]))
	mouse_x, mouse_y := rl.GetMouseX(), rl.GetMouseY()
	mu.input_mouse_move(ctx, mouse_x, mouse_y)
	mu.input_scroll(ctx, 0, i32(rl.GetMouseWheelMove() * -30))


	

	//odinfmt: disable
	@static button_to_key := [?]RlToMuMouseMap{
    {.LEFT, .LEFT},
    {.RIGHT, .RIGHT},
    {.MIDDLE, .MIDDLE},
  }
  //odinfmt: enable

	for button in button_to_key {
		if rl.IsMouseButtonPressed(button.rl_button) {
			mu.input_mouse_down(ctx, mouse_x, mouse_y, button.mu_button)
		} else if rl.IsMouseButtonReleased(button.rl_button) {
			mu.input_mouse_up(ctx, mouse_x, mouse_y, button.mu_button)
		}
	}
	
	//odinfmt: disable
  @static keys_to_check := [?]RlToMuKeyMap{
    {.LEFT_SHIFT,     .SHIFT},
    {.RIGHT_SHIFT,    .SHIFT},
    {.LEFT_CONTROL,   .CTRL},
    {.RIGHT_CONTROL,  .CTRL},
    {.LEFT_ALT,       .ALT},
    {.RIGHT_ALT,      .ALT},
    {.ENTER,          .RETURN},
    {.KP_ENTER,       .RETURN},
    {.BACKSPACE,      .BACKSPACE},
  }
	//odinfmt: enable

	for key in keys_to_check {
		if rl.IsKeyPressed(key.rl_key) {
			mu.input_key_down(ctx, key.mu_key)
		} else if rl.IsKeyReleased(key.rl_key) {
			mu.input_key_up(ctx, key.mu_key)
		}
	}
}

render_ui :: proc(ctx: ^mu.Context) {
	texture := atlas
	render_texture :: proc "contextless" (
		rect: mu.Rect,
		pos: [2]i32,
		color: mu.Color,
		atlas: rl.Texture,
	) {
		src := rl.Rectangle{cast(f32)rect.x, cast(f32)rect.y, cast(f32)rect.w, cast(f32)rect.h}
		pos := rl.Vector2{cast(f32)pos.x, cast(f32)pos.y}
		rl.DrawTextureRec(atlas, src, pos, transmute(rl.Color)color)
	}

	rl.BeginScissorMode(0, 0, rl.GetScreenWidth(), rl.GetScreenWidth())
	defer rl.EndScissorMode()

	cmd: ^mu.Command
	for variant in mu.next_command_iterator(ctx, &cmd) {
		#partial switch cmd in variant {
		case ^mu.Command_Clip:
			rl.EndScissorMode()
			rl.BeginScissorMode(cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h)
		case ^mu.Command_Rect:
			rl.DrawRectangle(
				cmd.rect.x,
				cmd.rect.y,
				cmd.rect.w,
				cmd.rect.h,
				transmute(rl.Color)(cmd.color),
			)
		case ^mu.Command_Text:
			pos := [2]i32{cmd.pos.x, cmd.pos.y}
			for ch in cmd.str {
				if ch & 0xc0 != 0x80 {
					r := min(int(ch), 127)
					rect := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + r]
					render_texture(rect, pos, cmd.color, texture)
					pos.x += rect.w
				}
			}
		case ^mu.Command_Icon:
			rect := mu.default_atlas[cmd.id]
			x := cmd.rect.x + (cmd.rect.w - rect.w) / 2
			y := cmd.rect.y + (cmd.rect.h - rect.h) / 2
			render_texture(rect, {x, y}, cmd.color, texture)
		}
	}
}
