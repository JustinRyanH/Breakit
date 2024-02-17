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


input_stream: [dynamic]input.UserInput

get_current_frame :: proc(idx: int) -> (frame_input: input.FrameInput, err: input.InputError) {
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
		defer {
			clear(&ctx.events)
			free_all(context.temp_allocator)
		}

		dll_time, dll_time_err := os.last_write_time_by_name(game_api_file_path(game_api))
		reload := dll_time_err == os.ERROR_NONE && game_api.dll_time != dll_time

		if reload {
			game_api = game_api_hot_load(game_api)
		}

		rl_platform.load_input(&ctx.mui)
		if rl.IsKeyPressed(.F2) {
			switch _ in ctx.playback {
			case input.Recording:
				game_api.setup()

				replay := input.Replay{}
				replay.last_frame_index = len(input_stream) - 1
				replay.active = true

				ctx.playback = replay
			case input.Replay:
				clear(&input_stream)
				ctx.playback = input.Recording{0}
				game_api.setup()
			}
		}

		current_frame: input.FrameInput
		err: input.InputError

		switch pb in ctx.playback {
		case input.Recording:
			add_frame()

			current_frame, err = get_current_frame(pb.index)
		case input.Replay:
			current_frame, err = get_current_frame(pb.index)
		}
		if err != nil {
			fmt.printf("Error: %v\n", err)
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

		for ctx_evt in ctx.events {
			switch evt in ctx_evt {
			case game.StepEvent:
				pb, ok := &ctx.playback.(input.Replay)
				if ok {
					pb.index += 1
				}
			}
		}

		switch pb in &ctx.playback {
		case input.Recording:
			pb.index += 1
		case input.Replay:
			if pb.active {

				pb.index += 1
			}
			if pb.index >= len(input_stream) {
				pb.index = 0
				game_api.setup()
			}
		}
	}

	game_api.shutdown()
	game_api_unload(game_api)
}
