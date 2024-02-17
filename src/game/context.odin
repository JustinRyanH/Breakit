package game

import "input"

StepEvent :: struct {
	steps: int,
}

ContextEvents :: union {
	StepEvent,
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
