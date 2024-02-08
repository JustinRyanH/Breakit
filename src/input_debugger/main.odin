package input

import "core:fmt"
import math "core:math/linalg"
import "core:os"
import "core:strings"
import "core:unicode/utf8"

import mu "vendor:microui"
import rl "vendor:raylib"

import game "../game"
import rl_platform "../raylib_platform"

ScreenWidth :: 800
ScreenHeight :: 450

input_reps: [dynamic]ButtonInputRep
db_state: InputDebuggerState

// We are going to write out the frames into a file, the zeroth iteration will
// follow bad form, and not even write in a header with a version, however, after
// this we will immediately resovle this problem before bringing it to the game
// [x] Write the inputs to a file 
// [x] Hitting input displays on the screen which input from Kenney assets, it will color gray is not hit, red if hit
// [ ] Display the same keys being hit on the playback side
// [ ] Generate a new file every time the apps starts up
// [ ] Create a raygui list of files in the logs directory
// [ ] Allow selecting a file to play back

RlToMuMouseMap :: struct {
	rl_button: rl.MouseButton,
	mu_button: mu.Mouse,
}

RlToMuKeyMap :: struct {
	rl_key: rl.KeyboardKey,
	mu_key: mu.Key,
}

ray_mu_load_input :: proc(ctx: ^mu.Context) {
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

ray_mu_render :: proc(ctx: ^mu.Context, texture: rl.Texture) {
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
}


main :: proc() {
	rl.InitWindow(ScreenWidth, ScreenHeight, "Input Debugger")
	rl.SetTargetFPS(30.0)
	defer rl.CloseWindow()

	ctx := new(mu.Context)
	defer free(ctx)

	mu.init(ctx)
	ctx.text_width = mu.default_atlas_text_width
	ctx.text_height = mu.default_atlas_text_height

	pixels := make([][4]u8, mu.DEFAULT_ATLAS_WIDTH * mu.DEFAULT_ATLAS_HEIGHT)
	defer delete(pixels)
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
	atlas := rl.LoadTextureFromImage(atlas_image)
	defer rl.UnloadTexture(atlas)

	db_state.writer = game_input_writer_create("logs/input.log")
	db_state.reader = game_input_reader_create("logs/input.log")
	db_state.vcr_state = .Recording

	if (os.exists("logs/input.log")) {
		os.remove("logs/input.log")
	}

	err := game_input_writer_open(&db_state.writer)
	if err != nil {
		fmt.printf("Error opening input file: %v\n", err)
		return
	}

	input_reps = make([dynamic]ButtonInputRep)
	defer delete(input_reps)

	input_rep_create_all()
	defer input_rep_cleanup_all()

	db_state.frame = rl_platform.update_frame(game.FrameInput{})
	game_input_writer_insert_frame(&db_state.writer, db_state.frame)

	for {
		ray_mu_load_input(ctx)

		err := read_write_frame()
		if err != nil {
			fmt.printf("Error: %v", err)
			return
		}

		if rl.IsKeyPressed(.F5) {
			err = read_write_toggle()
			if err != nil {
				fmt.printf("Error: %v", err)
				return
			}
		}

		if rl.WindowShouldClose() {
			break
		}


		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground(rl.BLACK)

		for _, i in input_reps {
			input_rep_record_input(&input_reps[i], db_state.frame)
			input_rep_draw_all(&input_reps[i])
		}

		ray_mu_render(ctx, atlas)
	}
}
