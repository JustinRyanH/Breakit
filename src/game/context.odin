package game

import "input"

StepEvent :: struct {
	steps: int,
}

BeginLoop :: struct {
	start_idx: int,
	end_idx:   int,
}

ContextEvents :: union {
	StepEvent,
	BeginLoop,
}

import mu "../microui"
Context :: struct {
	mui:           mu.Context,
	playback:      input.Playback,
	events:        [dynamic]ContextEvents,

	// Draw Commands
	cmds:          PlatformCommands,
	draw_cmds:     PlatformDrawCommands,

	// Debug Info
	last_frame_id: int,
}
