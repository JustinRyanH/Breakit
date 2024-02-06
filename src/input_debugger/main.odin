package input

import "core:fmt"
import math "core:math/linalg"
import "core:os"
import "core:testing"

import game "../game"
import rl_platform "../raylib_platform"
import rl "vendor:raylib"


panel_rect := rl.Rectangle{0, 0, 400, 450}
panel_content_rect := rl.Rectangle{20, 40, 1_500, 10_000}
panel_view := rl.Rectangle{}
panel_scroll := rl.Vector2{99, -20}
// We are going to write out the frames into a file, the zeroth iteration will
// follow bad form, and not even write in a header with a version, however, after
// this we will immediately resovle this problem before bringing it to the game
// [x] Write the inputs to a file 
// [ ] Hitting input displays on the screen which input from Kenney assets, it will color gray is not hit, red if hit
// [ ] Generate a new file every time the apps starts up
// [ ] Create a raygui list of files in the logs directory
// [ ] Allow selecting a file to play back
// [ ] Display the same keys being hit on the playback side

draw_gui :: proc(frame: game.FrameInput) {
	grid_rect := rl.Rectangle {
		panel_rect.x + panel_scroll.x,
		panel_rect.y + panel_scroll.y,
		panel_content_rect.width + 12,
		panel_content_rect.height + 12,
	}
	rl.GuiScrollPanel(panel_rect, nil, panel_content_rect, &panel_scroll, &panel_view)
	{
		rl.BeginScissorMode(
			cast(i32)(panel_rect.x),
			cast(i32)(panel_rect.y),
			cast(i32)(panel_rect.width - 12),
			cast(i32)(panel_rect.height - 12),
		)
		defer rl.EndScissorMode()
		rl.GuiGrid(grid_rect, nil, 16, 3, nil)
		text := fmt.ctprintf("Frame: %v", frame.current_frame)
		text_width := cast(f32)(rl.MeasureText(text, 12)) + 20
		panel_content_rect.width = math.max(text_width, panel_content_rect.width)

		rl.DrawText(text, cast(i32)(grid_rect.x + 5), cast(i32)(grid_rect.y + 20), 12, rl.MAROON)
	}
}

draw_input :: proc(frame: game.FrameInput) {

}

main :: proc() {
	rl.InitWindow(800, 450, "Input Debugger")
	rl.SetTargetFPS(30.0)
	defer rl.CloseWindow()

	panel_rect.x = 800 - panel_rect.width


	file_handle, err := os.open(
		"./logs/input.log",
		os.O_WRONLY | os.O_APPEND | os.O_CREATE | os.O_TRUNC,
	)
	if err != os.ERROR_NONE {
		fmt.printf("Error: %v\n", err)
		return
	}
	defer os.close(file_handle)


	frame := rl_platform.update_frame(game.FrameInput{})
	write_size, write_err := os.write_ptr(
		file_handle,
		&frame.current_frame,
		size_of(frame.current_frame),
	)
	if write_err != os.ERROR_NONE {
		fmt.printf("Error: %v\n", write_err)
		return
	}

	for {
		frame = rl_platform.update_frame(frame)
		write_size, write_err = os.write_ptr(
			file_handle,
			&frame.current_frame,
			size_of(frame.current_frame),
		)
		if write_err != os.ERROR_NONE {
			fmt.printf("Error: %v\n", write_err)
			return
		}

		if rl.WindowShouldClose() {
			break
		}


		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground(rl.BLACK)

		draw_input(frame)
		draw_gui(frame)

		rl.DrawText(fmt.ctprintf("P(%v)", panel_scroll), 10, 10, 20, rl.MAROON)
	}
}

InputFileHeader :: struct {
	version:     u16le,
	header_size: u32le,
}

GameInputFileError :: enum {
	NotFound,
	NoAccess,
	FileTooBig,
	MismatchWriteSize,
	SystemError, // EFBIG, ENOSPC, EROFS
}

GameInputWriter :: struct {
	file_path:   string,
	file_handle: os.Handle,
	is_open:     bool,

	// Meta Data about file
	header:      InputFileHeader,
}

game_input_writer_create :: proc(file_path: string) -> (writer: GameInputWriter) {
	writer.file_path = file_path
	writer.header.version = 1
	writer.header.header_size = size_of(InputFileHeader)
	return
}

game_input_open :: proc(writer: ^GameInputWriter) -> GameInputFileError {
	handle, err := os.open(
		writer.file_path,
		os.O_WRONLY | os.O_APPEND | os.O_CREATE | os.O_TRUNC,
		0o644,
	)
	if err == os.ERROR_NONE {
		writer.file_handle = handle
		writer.is_open = true
		return nil
	}
	if err == os.ENOENT {
		return .NotFound
	}
	if err == os.EACCES {
		return .NoAccess
	}

	return .SystemError
}

// Return true if the file was closed successfully
game_input_close :: proc(writer: ^GameInputWriter) -> bool {
	success := os.close(writer.file_handle)
	if (success) {
		writer.is_open = false
	}
	return success
}

game_input_write_header :: proc(writer: ^GameInputWriter) -> GameInputFileError {
	write_size, err := os.write_ptr(writer.file_handle, &writer.header, size_of(writer.header))
	if err != os.ERROR_NONE {
		if err == os.EFBIG {
			return .FileTooBig
		}
		return .SystemError
	}

	if write_size != size_of(writer.header) {
		return .MismatchWriteSize
	}


	return nil
}

@(test)
test_input_writer :: proc(t: ^testing.T) {
	writer := game_input_writer_create("bin/test.log")
	game_input_open(&writer)
	defer {
		if writer.is_open {
			game_input_close(&writer)
		}
		delete_err := os.remove(writer.file_path)
		testing.expect(
			t,
			delete_err == os.ERROR_NONE,
			fmt.tprintf("Unable to delete test file: #%v", delete_err),
		)
	}

	game_input_write_header(&writer)
}


@(test)
test_input_reading_writing :: proc(t: ^testing.T) {
	test_file_path := "./logs/test-input.log"
	current_frame := game.UserInput{}
	current_frame.meta.frame_id = 1
	current_frame.meta.frame_delta = 1 / 60
	current_frame.meta.screen_width = 100
	current_frame.meta.screen_height = 120
	current_frame.mouse.pos = math.Vector2f32{15, 15}
	current_frame.keyboard.space_down = true

	file_opened := false
	file_handle, err := os.open(
		test_file_path,
		os.O_WRONLY | os.O_APPEND | os.O_CREATE | os.O_TRUNC,
		0o644,
	)
	if err != os.ERROR_NONE {
		fmt.printf("Error: %v\n", err)
		return
	}
	file_opened = true

	defer {
		if (file_opened) {
			os.close(file_handle)
		}
		delete_err := os.remove(test_file_path)
		if delete_err != os.ERROR_NONE {
			fmt.printf("Error: %v\n", err)
		}
	}


	write_size, write_err := os.write_ptr(file_handle, &current_frame, size_of(current_frame))
	if write_err != os.ERROR_NONE {
		fmt.printf("Error: %v\n", write_err)

		return
	}
	os.close(file_handle)
	file_opened = false

	file_handle, err = os.open(test_file_path, os.O_RDONLY)
	if err != os.ERROR_NONE {
		fmt.printf("Error: %v\n", err)
		return
	}
	file_opened = true

	read_frame := game.UserInput{}
	data, read_err := os.read_ptr(file_handle, &read_frame, size_of(read_frame))

	testing.expect(t, current_frame == read_frame, "Able to read/write frames from system")
}
