package main

import "core:bytes"
import "core:fmt"

import rl "vendor:raylib"

import "../game"
import "../game/input"

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

loop_return_to_start_of_loop :: proc(loop: ^input.Loop, game_api: GameAPI) {
	loop.index = loop.start_index

	tb: bytes.Buffer
	bytes.buffer_init(&tb, loop.start_index_data)

	stream := bytes.buffer_to_stream(&tb)
	game_api.load_from_stream(stream)

}
