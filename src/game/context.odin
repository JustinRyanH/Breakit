package game

import "input"

import mu "../microui"
Context :: struct {
	mui:       mu.Context,
	frame:     input.FrameInput,

	// Draw Commands
	cmds:      PlatformCommands,
	draw_cmds: PlatformDrawCommands,
}
