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
	NoMoreFrames,
}

GameInputFileError :: enum {
	HandleClosedOrReadOnly,
	FileNotOpen,
	NoAccess,
	MismatchWriteSize,
	NotInReadMode,
	NotInWriteMode,
	SystemError,
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

GameInputIO :: union {
	GameInputReader,
	GameInputWriter,
}

game_input_close :: proc(io: ^GameInputIO) {
	switch v in io {
	case GameInputWriter:
		game_input_writer_close(&v)
	case GameInputReader:
		game_input_reader_close(&v)
	}
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
	when ODIN_OS == .Darwin {
	}
	return .SystemError

}

game_input_reader_close :: proc(reader: ^GameInputReader) -> bool {
	when ODIN_OS == .Darwin {
		success := os.close(reader.file_handle)
		if (success) {
			reader.is_open = false
		}
		return true
	} else when ODIN_OS == .Windows {
		err := os.close(reader.file_handle)
		if (err != os.ERROR_NONE) {
			reader.is_open = false
			return true
		}

	}
	return false
}

game_input_reader_read_input :: proc(
	reader: ^GameInputReader,
) -> (
	new_frame: game.UserInput,
	err: GameInputError,
) {
	if !reader.is_open {
		err = .FileNotOpen
		return
	}

	read_size, read_err := os.read_ptr(reader.file_handle, &new_frame, size_of(game.UserInput))
	if read_err != os.ERROR_NONE {
		when ODIN_OS == .Darwin {
			if read_err == os.EBADF {
				err = .HandleClosedOrReadOnly
				return
			}
			err = .SystemError
			return
		} else when ODIN_OS == .Windows {
			if read_err == os.ERROR_EOF {
				err = .NoMoreFrames
				return
			}
			err = .SystemError
			return
		}
	}
	if read_size == 0 {
		err = .NoMoreFrames
		return
	}
	if read_size != size_of(new_frame) {
		err = .MismatchWriteSize
		return
	}

	return
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
			return .SystemError
		}

		if write_size != size_of(writer.header) {
			return .MismatchWriteSize
		}
		return nil
	}

	return .SystemError
}

// Return true if the file was closed successfully
game_input_writer_close :: proc(writer: ^GameInputWriter) -> bool {
	when ODIN_OS == .Darwin {
		success := os.close(writer.file_handle)
		if (success) {
			writer.is_open = false
		}
		return true
	} else when ODIN_OS == .Windows {
		err := os.close(writer.file_handle)
		if (err != os.ERROR_NONE) {
			writer.is_open = false
			return true
		}
	}
	return false
}

game_input_writer_insert_frame :: proc(
	writer: ^GameInputWriter,
	frame: game.FrameInput,
) -> GameInputError {
	if !writer.is_open {
		return .FileNotOpen
	}
	current_frame := frame.current_frame

	write_size, err := os.write_ptr(writer.file_handle, &current_frame, size_of(current_frame))
	if err != os.ERROR_NONE {
		return .SystemError
	}

	if write_size != size_of(current_frame) {
		return .MismatchWriteSize
	}
	return nil
}

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
