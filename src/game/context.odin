package game

import "input"

StepEvent :: struct {
	steps: int,
}

JumpToFrame :: struct {
	frame_idx: int,
}

ContextEvents :: union {
	StepEvent,
	JumpToFrame,
}

import mu "../microui"
Context :: struct {
	mui:       mu.Context,
	playback:  input.Playback,
	events:    [dynamic]ContextEvents,

	// Draw Commands
	cmds:      PlatformCommands,
	draw_cmds: PlatformDrawCommands,
}
