package main


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
	u_input.meta.frame_id = len(input_stream)
	append(&input_stream, u_input)
}

InputErroringError :: union {
	os.Errno,
}

InputRecordingFile :: struct {
	handle:   os.Handle,
	filepath: string,
	ready:    bool,
	length:   int,
}

input_recording_begin :: proc(ipf: ^InputRecordingFile, file: string) -> InputErroringError {
	handle, err := os.open(file, os.O_WRONLY | os.O_TRUNC | os.O_CREATE)
	if err != os.ERROR_NONE {
		return err
	}

	ipf.filepath = file
	ipf.ready = true
	ipf.handle = handle

	return os.ERROR_NONE
}

input_recording_append :: proc(
	ipf: ^InputRecordingFile,
	user_input: ^input.UserInput,
) -> os.Errno {
	_, err := os.write_ptr(ipf.handle, user_input, size_of(input.UserInput))
	return err
}

input_recording_write_header :: proc(ipf: ^InputRecordingFile) {
	header := input.get_file_header()
	os.write_ptr(ipf.handle, &header, size_of(header))
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

	ipf := InputRecordingFile{}
	input_recording_begin(&ipf, "logs/input.log")
	input_recording_write_header(&ipf)

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
			case input.Replay:
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
				#partial switch pb in &ctx.playback {
				case input.Replay:
					pb.index += 1
				case input.Loop:
					pb.index += 1
				}

			case game.Resume:
				loop, is_loop := ctx.playback.(input.Loop)
				if is_loop {
					rp := input.Replay{}
					rp.index = loop.index
					rp.active = loop.active
					rp.last_frame_index = len(input_stream) - 1
					ctx.playback = rp
				}
			case game.BeginLoop:
				game_api.setup()

				loop := input.Loop{}
				loop.last_frame_index = len(input_stream) - 1
				loop.start_index = evt.start_idx
				loop.end_index = evt.end_idx
				loop.state = .PlayingToStartIndex
				pb, ok := &ctx.playback.(input.Replay)
				if ok {
					loop.active = pb.active
				}
				lp, lp_ok := &ctx.playback.(input.Loop)
				if lp_ok {
					loop.active = lp.active
				}

				ctx.playback = loop
				ctx.last_frame_id = 0
			}

		}

		switch pb in &ctx.playback {
		case input.Recording:
			pb.index += 1
		case input.Loop:
			if pb.state == .Looping {
				if pb.active {
					pb.index += 1
				}
				if pb.index > pb.end_index {
					loop_return_to_start_of_loop(&pb, game_api)
				}
			}
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
