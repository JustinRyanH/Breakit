package game

PlatformCommands :: struct {
	should_close_game: proc() -> bool,
	begin_drawing:     proc(),
	end_drawing:       proc(),
}
