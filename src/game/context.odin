package game

import "input"


PauseCmd :: struct {}
ResumeCmd :: struct {}
ReplayCmd :: struct {}

FrameCommand :: union {
	PauseCmd,
	ResumeCmd,
	ReplayCmd,
}

import mu "../microui"
Context :: struct {
	mui:       mu.Context,
	frame_cmd: FrameCommand,

	// Draw Commands
	cmds:      PlatformCommands,
	draw_cmds: PlatformDrawCommands,
}
