package main


import "core:c/libc"
import "core:dynlib"
import "core:fmt"
import "core:os"
import "core:path/filepath"

import rl "vendor:raylib"

import "../game"
import "../game/input"
import rl_platform "../raylib_platform"
import ta "../tracking_alloc"

frame_zero: rawptr = nil


Recording :: struct {
	index: int,
}

Replay :: struct {
	index: int,
}


Playback :: union {
	Recording,
	Replay,
}

InputPlaybackError :: enum {
	StreamOverflow,
}

PlatformError :: union {
	InputPlaybackError,
}


input_stream: [dynamic]input.UserInput

get_current_frame :: proc(idx: int) -> (frame_input: input.FrameInput, err: PlatformError) {
	if (idx >= len(input_stream)) {
		err = .StreamOverflow
		return
	}
	if (idx > 0) {
		frame_input.last_frame = input_stream[idx - 1]
	}
	frame_input.current_frame = input_stream[idx]
	return
}


add_frame :: proc() {
	u_input := rl_platform.get_current_user_input()
	u_input.meta.frame_id = len(&input_stream)
	append(&input_stream, u_input)
}


main :: proc() {
	default_allocator := context.allocator
	tracking_allocator: ta.Tracking_Allocator
	ta.tracking_allocator_init(&tracking_allocator, default_allocator)
	context.allocator = ta.allocator_from_tracking_allocator(&tracking_allocator)
	defer ta.tracking_allocator_destroy(&tracking_allocator)

	rl.InitWindow(800, 600, "Breakit")
	rl.SetTargetFPS(60.0)
	defer rl.CloseWindow()

	input_stream = make([dynamic]input.UserInput, 0, 1024)
	playback: Playback = Recording{}

	ctx := rl_platform.new_context()
	defer rl_platform.deinit_game_context(ctx)
	rl_platform.setup_raylib_mui(&ctx.mui)
	defer rl_platform.destroy_raylib_mui()

	game_api, game_api_ok := game_api_load(0, "game", "./bin")

	if !game_api_ok {
		fmt.println("Failed to load Game API")
		return
	}

	game_api.update_ctx(ctx)
	game_api.init()
	game_api.setup()

	for {
		defer free_all(context.temp_allocator)

		dll_time, dll_time_err := os.last_write_time_by_name(game_api_file_path(game_api))
		reload := dll_time_err == os.ERROR_NONE && game_api.dll_time != dll_time

		if reload {
			game_api = game_api_hot_load(game_api)
		}

		if rl.IsKeyReleased(.F2) {
			game_api.setup()
		}

		current_frame: input.FrameInput
		err: PlatformError

		switch pb in playback {
		case Recording:
			add_frame()

			current_frame, err = get_current_frame(pb.index)
		case Replay:
			current_frame, err = get_current_frame(pb.index)
		}
		if err != nil {
			fmt.printf("Error: %v", err)
			return
		}

		game_api.update_ctx(ctx)
		should_exit := game_api.update(current_frame)
		{
			rl.BeginDrawing()
			defer rl.EndDrawing()


			game_api.draw()

			rl.DrawFPS(10, 10)
			rl_platform.render_mui(&ctx.mui)
		}


		if (should_exit) {
			break
		}
		switch pb in &playback {
		case Recording:
			pb.index += 1
		case Replay:
			pb.index += 1
		}
	}

	game_api.shutdown()
	game_api_unload(game_api)
}
