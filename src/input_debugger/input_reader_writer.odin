package input

import "core:fmt"
import math "core:math/linalg"
import "core:os"
import "core:testing"

import game "../game"

InputFileHeader :: struct {
	version:     u16le,
	header_size: u32le,
	did_finish:  bool,
	frame_count: u64le,
}

InputParsingError :: enum {
	BadHeader,
	InvalidHeaderVersion,
	InvalidHeaderSize,
}

GameInputFileError :: enum {
	NotFound,
	NoAccess,
	FileTooBig,
	MismatchWriteSize,
	SystemError, // EFBIG, ENOSPC, EROFS
}

GameInputError :: union {
	InputParsingError,
	GameInputFileError,
}

GameInputReader :: struct {
	file_path:   string,
	file_handle: os.Handle,
	is_open:     bool,

	// Meta Data about file
	header:      InputFileHeader,
}

GameInputWriter :: struct {
	file_path:   string,
	file_handle: os.Handle,
	is_open:     bool,

	// Meta Data about file
	header:      InputFileHeader,
}

// Create Input Reader, does not open the file
game_input_reader_create :: proc(file_path: string) -> (reader: GameInputReader) {
	reader.file_path = file_path
	return
}

game_input_reader_open :: proc(reader: ^GameInputReader) -> GameInputError {
	handle, err := os.open(reader.file_path, os.O_RDONLY)
	if err == os.ERROR_NONE {
		reader.file_handle = handle
		reader.is_open = true

		size, read_err := os.read_ptr(reader.file_handle, &reader.header, size_of(reader.header))
		if read_err != os.ERROR_NONE {
			return .SystemError
		}
		if size != size_of(reader.header) {
			return .BadHeader
		}
		if reader.header.version != 1 {
			return .InvalidHeaderVersion
		}

		if reader.header.header_size != size_of(reader.header) {
			return .InvalidHeaderSize
		}

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

game_input_writer_create :: proc(file_path: string) -> (writer: GameInputWriter) {
	writer.file_path = file_path
	writer.header.version = 1
	writer.header.header_size = size_of(InputFileHeader)
	return
}

game_input_writer_open :: proc(writer: ^GameInputWriter) -> GameInputError {
	handle, err := os.open(
		writer.file_path,
		os.O_WRONLY | os.O_APPEND | os.O_CREATE | os.O_TRUNC,
		0o644,
	)
	if err == os.ERROR_NONE {
		writer.file_handle = handle
		writer.is_open = true
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
	if err == os.ENOENT {
		return .NotFound
	}
	if err == os.EACCES {
		return .NoAccess
	}

	return .SystemError
}

// Return true if the file was closed successfully
game_input_writer_close :: proc(writer: ^GameInputWriter) -> bool {
	success := os.close(writer.file_handle)
	if (success) {
		writer.is_open = false
	}
	return success
}

@(test)
test_input_writer :: proc(t: ^testing.T) {
	writer := game_input_writer_create("bin/test.log")
	reader := game_input_reader_create("bin/test.log")
	err := game_input_writer_open(&writer)
	testing.expect(t, err == nil, fmt.tprintf("Expected No Error, Got: %v", err))

	defer {
		if writer.is_open {
			game_input_writer_close(&writer)
		}
		delete_err := os.remove(writer.file_path)
		testing.expect(
			t,
			delete_err == os.ERROR_NONE,
			fmt.tprintf("Unable to delete test file: #%v", delete_err),
		)
	}

	testing.expect(t, err == nil, fmt.tprintf("Expected No Error, Go Error: %v", err))
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
