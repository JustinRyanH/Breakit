package game


import mu "../microui"
Context :: struct {
	mui:       mu.Context,
	frame:     FrameInput,
	cmds:      PlatformCommands,
	draw_cmds: PlatformDrawCommands,
}
