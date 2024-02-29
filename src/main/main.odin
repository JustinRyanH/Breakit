package main


import "core:bytes"
import "core:c/libc"
import "core:dynlib"
import "core:fmt"
import "core:math"
import "core:os"
import "core:path/filepath"

import rl "vendor:raylib"

import "../game"
import "../game/input"
import rl_platform "../raylib_platform"
import ta "../tracking_alloc"

frame_zero: rawptr = nil


FPS: i32 = 60

input_stream: [dynamic]input.UserInput

loop_fast_forward :: proc(loop: ^input.Loop, game_api: GameAPI) -> (frame: input.FrameInput) {
	target_time := rl.GetTime() + (1 / cast(f64)FPS)
	time := rl.GetTime()

	pb_index := loop.index
	for idx in pb_index ..= loop.start_index {
		loop.index = idx
		temp_frame, err := get_current_frame(idx)
		frame = temp_frame
		if err != nil {
			fmt.printf("Error: %v\n", err)
			return
		}
		game_api.update(temp_frame)

		time = rl.GetTime()
		if time > target_time {
			return
		}
	}
	return
}


loop_load_frame_data :: proc(loop: ^input.Loop, game_api: GameAPI) {
	game_size := game_api.mem_size()
	tb: bytes.Buffer
	bytes.buffer_init_allocator(&tb, 0, game_size)

	stream := bytes.buffer_to_stream(&tb)
	err := game_api.save_to_stream(stream)
	if err != .None {
		panic(fmt.tprintf("Save to Stream Error: %v", err))
	}

	loop.start_index_data = bytes.buffer_to_bytes(&tb)
	loop.state = .Looping

}

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

	rl_platform.new_platform_storage()
	defer rl_platform.free_platform_storage()

	rl.InitWindow(800, 600, "Breakit")
	rl.SetTargetFPS(FPS)
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
			switch pb in &ctx.playback {
			case input.Recording:
				game_api.setup()
				ctx.last_frame_id = 0

				replay := input.Replay{}
				replay.last_frame_index = len(input_stream) - 1
				replay.active = true

				ctx.playback = replay
			case input.ReplayTo, input.Replay:
				clear(&input_stream)
				ctx.last_frame_id = 0
				ctx.playback = input.Recording{0}
				game_api.setup()
			case input.Loop:
				delete(pb.start_index_data)

				ctx.last_frame_id = 0
				ctx.playback = input.Recording{0}
				game_api.setup()
			}
		}

		current_frame: input.FrameInput
		err: input.InputError

		target_time := rl.GetTime() + (1 / cast(f64)FPS)
		time := rl.GetTime()
		switch pb in &ctx.playback {
		case input.Recording:
			add_frame()

			current_frame, err = get_current_frame(pb.index)
		case input.ReplayTo:
			// I see a lot code duplication here. I think
			// just need to combine ReplayTo into Loop,
			// and make it a special state
			pb_index := pb.index
			for idx in pb.index ..= pb.target_index {
				pb.index = idx
				temp_frame, err := get_current_frame(idx)
				if err != nil {
					fmt.printf("Error: %v\n", err)
					return
				}
				game_api.update(temp_frame)

				time = rl.GetTime()
				if time > target_time {
					current_frame = temp_frame
					break
				}
			}
			if time < target_time {
				ctx.playback = input.Replay{pb.target_index, len(input_stream) - 1, pb.was_active}
			}
		case input.Loop:
			switch pb.state {
			case .PlayingToStartIndex:
				current_frame = loop_fast_forward(&pb, game_api)

				if pb.index == pb.start_index {
					loop_load_frame_data(&pb, game_api)
				}
			case .Looping:
				current_frame, err = get_current_frame(pb.index)
				if err != nil {
					panic(fmt.tprintf("Frame Err: %v", err))
				}
			}
		case input.Replay:
			current_frame, err = get_current_frame(pb.index)
		}
		if err != nil {
			fmt.printf("Error: %v\n", err)
			return
		}

		{
			rl.BeginDrawing()
			defer rl.EndDrawing()


			game_api.update_ctx(ctx)
			should_exit := game_api.update(current_frame)


			game_api.draw()

			rl.DrawFPS(10, 10)
			rl_platform.render_mui(&ctx.mui)

			if (should_exit) {
				break
			}
		}


		for ctx_evt in ctx.events {
			switch evt in ctx_evt {
			case game.StepEvent:
				pb, ok := &ctx.playback.(input.Replay)
				if ok {
					pb.index += 1
				}
			case game.JumpToFrame:
				game_api.setup()
				ctx.last_frame_id = 0

				pb, ok := &ctx.playback.(input.Replay)
				if ok {
					ctx.playback = input.ReplayTo {
						0,
						evt.frame_idx,
						len(input_stream) - 1,
						pb.active,
					}
				} else {
					panic("Can only Jump to Frame from Playback")
				}
			case game.BeginLoop:
				game_api.setup()

				loop := input.Loop{}
				loop.last_frame_index = len(input_stream) - 1
				loop.start_index = evt.start_idx
				loop.end_index = evt.end_idx
				loop.state = .PlayingToStartIndex

				ctx.playback = loop
				ctx.last_frame_id = 0
			}

		}

		switch pb in &ctx.playback {
		case input.Recording:
			pb.index += 1
		case input.Loop:
			if pb.state == .Looping {
				pb.index += 1
				if pb.index > pb.end_index {
					pb.index = pb.start_index

					tb: bytes.Buffer
					bytes.buffer_init(&tb, pb.start_index_data)

					stream := bytes.buffer_to_stream(&tb)
					game_api.load_from_stream(stream)
				}
			}
		case input.ReplayTo:
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
