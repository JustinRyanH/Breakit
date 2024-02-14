package input

import "core:fmt"
import math "core:math/linalg"
import "core:os"
import "core:testing"

import game "../game"


@(test)
test_input_writer :: proc(t: ^testing.T) {
	current_frame := game.UserInput{}
	current_frame.meta.frame_id = 1
	current_frame.meta.frame_delta = 1 / 60
	current_frame.meta.screen_width = 100
	current_frame.meta.screen_height = 120
	current_frame.mouse.pos = math.Vector2f32{15, 15}
	current_frame.keyboard.space_down = true

	frame_input := game.FrameInput{}
	frame_input.current_frame = current_frame

	writer := game_input_writer_create("bin/test.log")
	reader := game_input_reader_create("bin/test.log")
	err := game_input_writer_open(&writer)
	testing.expect(t, err == nil, fmt.tprintf("Expected No Error, Got: %v", err))

	defer {
		if writer.is_open {
			game_input_writer_close(&writer)
			testing.expect(t, writer.is_open == false, "Expected Writer to be Closed")
		}
		if reader.is_open {
			game_input_reader_close(&reader)
			testing.expect(t, writer.is_open == false, "Expected Reader to be Closed")
		}
	}
	defer {
		delete_err := os.remove(writer.file_path)
		testing.expect(
			t,
			delete_err == os.ERROR_NONE,
			fmt.tprintf("Unable to delete test file: #%v", delete_err),
		)
	}

	testing.expect(t, err == nil, fmt.tprintf("Expected No Error, Go Error: %v", err))

	err = game_input_writer_insert_frame(&writer, frame_input)
	testing.expect(t, err == nil, fmt.tprintf("Expected No Error, Got: %v", err))

	game_input_writer_close(&writer)

	err = game_input_reader_open(&reader)
	testing.expect(t, err == nil, fmt.tprintf("Expected No Error, Got: %v", err))
	testing.expect(t, reader.header.version == 1, "Expected Version to be 1")
	testing.expect(
		t,
		reader.header.header_size == size_of(InputFileHeader),
		fmt.tprintf(
			"Expected Header Size to be %v, Got: ",
			reader.header.header_size,
			size_of(InputFileHeader),
		),
	)

	input, read_err := game_input_reader_read_input(&reader)
	testing.expect(t, read_err == nil, fmt.tprintf("Expected No Error, Got: %v", read_err))
	testing.expect(t, input == current_frame, "Expected Frame to be the same")
}
