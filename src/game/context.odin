package game

import "input"

import mu "../microui"
Context :: struct {
	mui:       mu.Context,
	playback:  input.Playback,

	// Draw Commands
	cmds:      PlatformCommands,
	draw_cmds: PlatformDrawCommands,
}
