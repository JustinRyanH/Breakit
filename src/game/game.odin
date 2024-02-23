package game

import sa "core:container/small_array"
import "core:fmt"
import math "core:math/linalg"
import "core:math/rand"
import "core:mem"

import "./input"

import mu "../microui"


KbKey :: input.KeyboardKey
MouseBtn :: input.MouseButton

ObjectKind :: enum {
	Ball,
	Brick,
	Wall,
	Paddle,
}

DestroyEvent :: struct {
	handle: EntityHandle,
}

BeginFreeMovement :: struct {
	ball_handle: EntityHandle,
	direction:   Vector2,
	speed:       f32,
}

BallDeathEvent :: struct {
	ball: EntityHandle,
}

GameEvent :: union {
	DestroyEvent,
	BeginFreeMovement,
	BallDeathEvent,
}


StageWin :: struct {}

StageLose :: struct {}

StageTypes :: enum {
	StageMain,
	WinStage,
	StageLose,
}

Stages :: union {
	StageMain,
	StageWin,
	StageLose,
}

CollidableObject :: struct {
	kind:   ObjectKind,
	handle: EntityHandle,
	shape:  Shape,
}

Paddle :: struct {
	id:    EntityHandle,
	shape: Rectangle,
	color: Color,
	speed: f32,
}

Wall :: struct {
	id:    EntityHandle,
	shape: Rectangle,
}

LockedToEntity :: struct {
	handle: EntityHandle,
	offset: Vector2,
}

FreeMovement :: struct {
	direction: Vector2,
	speed:     f32,
}

BallState :: union {
	LockedToEntity,
	FreeMovement,
}

Brick :: struct {
	id:    EntityHandle,
	shape: Rectangle,
	color: Color,
	alive: bool,
}

Ball :: struct {
	id:    EntityHandle,
	shape: Circle,
	color: Color,
	state: BallState,
}

EntityHandle :: distinct Handle
Entity :: union {
	Paddle,
	Brick,
	Ball,
	Wall,
}

GameMemory :: struct {
	scene_width:  f32,
	scene_height: f32,

	// Game Entities
	stage:        Stages,

	// Game Entities
	entities:     DataPool(512, Entity, EntityHandle),
	event_queue:  RingBuffer(256, GameEvent),
}


ctx: ^Context
g_input: input.FrameInput
ball_collision_targets: [dynamic]CollidableObject
g_mem: ^GameMemory

current_input :: #force_inline proc() -> input.UserInput {
	return g_input.current_frame
}

@(export)
game_init :: proc() {
	g_mem = new(GameMemory)
}

@(export)
game_setup :: proc() {
	// Soft Reset, I want to crash if there is dangling handles between resets
	data_pool_reset(&g_mem.entities)

	g_mem.scene_width = 800
	g_mem.scene_height = 600


	stage_main := StageMain{}
	setup_next_stage(stage_main)
}

@(export)
game_update_context :: proc(new_ctx: ^Context) {
	ctx = new_ctx
}

@(export)
game_update :: proc(frame_input: input.FrameInput) -> bool {
	dt := input.frame_query_delta(frame_input)
	g_input = frame_input

	if (ctx.last_frame_id != get_frame_id(frame_input)) {
		update_gameplay(frame_input)
	}

	{
		mui_ctx := &ctx.mui
		mu.begin(mui_ctx)
		defer mu.end(mui_ctx)

		rp, is_replay := &ctx.playback.(input.Replay)
		if is_replay {
			mu.window(mui_ctx, "Replay Controls", {500, 100, 300, 175}, {.NO_CLOSE})
			mu.layout_row(mui_ctx, {-1})
			frame := cast(mu.Real)rp.index
			mu.slider(
				mui_ctx,
				&frame,
				0,
				cast(mu.Real)rp.last_frame_index,
				1,
				"%.0f",
				{.NO_INTERACT},
			)

			if (rp.active) {
				mu.layout_row(mui_ctx, {75})
				mu.checkbox(mui_ctx, "Active", &rp.active)
			} else {
				mu.layout_row(mui_ctx, {75, 50})
				mu.checkbox(mui_ctx, "Active", &rp.active)
				res := mu.button(mui_ctx, "Step")
				if .SUBMIT in res {
					append(&ctx.events, StepEvent{1})
				}
			}

			@(static)
			target_frame: mu.Real
			mu.layout_row(mui_ctx, {80, -1})
			res := mu.button(mui_ctx, "Jump to Frame")
			if .SUBMIT in res {
				append(&ctx.events, JumpToFrame{cast(int)target_frame})
			}
			mu.slider(mui_ctx, &target_frame, 0, cast(mu.Real)rp.last_frame_index, 1, "%.0f")

			mu.layout_row(mui_ctx, {80, 75, 75})
			res = mu.button(mui_ctx, "Loop Between")
			@(static)
			start_frame: mu.Real
			@(static)
			end_frame: mu.Real

			if (end_frame == 0) {
				end_frame = cast(mu.Real)rp.last_frame_index - 1
			}

			mu.slider(mui_ctx, &start_frame, 0, end_frame, 1, "From: %.0f")
			mu.slider(
				mui_ctx,
				&end_frame,
				start_frame,
				cast(mu.Real)rp.last_frame_index - 1,
				1,
				"To: %.0f",
			)
		}

	}

	ctx.last_frame_id = get_frame_id(frame_input)
	return ctx.cmds.should_close_game()
}

@(export)
game_draw :: proc() {
	game := g_mem
	width, height := g_mem.scene_width, g_mem.scene_height

	switch s in g_mem.stage {
	case StageMain:
		stage_main_draw(s)
	case StageLose:
		panic("LostStage is not implemented")
	case StageWin:
		panic("WinStage is not implemented")
	}
}


@(export)
game_shutdown :: proc() {
	free(g_mem)
}

@(export)
game_memory :: proc() -> rawptr {
	return g_mem
}

@(export)
game_hot_reloaded :: proc(mem: ^GameMemory) {
	g_mem = mem
}

update_gameplay :: proc(frame_input: input.FrameInput) {

	dt := input.frame_query_delta(frame_input)
	g_input = frame_input


	for event in ring_buffer_pop(&g_mem.event_queue) {
		switch evt in event {
		case BallDeathEvent:
			game_setup()
		case DestroyEvent:
			removed := data_pool_remove(&g_mem.entities, evt.handle)
			if !removed {
				fmt.println("Failed to remove brick at handle", evt)
			}
		case BeginFreeMovement:
			ball := get_ball(&g_mem.entities, evt.ball_handle)
			ball.state = FreeMovement{evt.direction, evt.speed}
		}
	}

	switch stage in g_mem.stage {
	case StageMain:
		stage_main_update(stage, frame_input)
	case StageWin:
		panic("Lose Stage Not implemented")
	case StageLose:
		panic("Lose Stage Not implemented")
	}

}

setup_next_stage :: proc(stage: Stages) {
	stage_cpy := stage
	switch s in &stage_cpy {
	case StageMain:
		setup_stage_main(&s)
	case StageWin:
		panic("Not main stage")
	case StageLose:
		panic("Not main stage")
	}
	g_mem.stage = stage_cpy
}

get_frame_id :: proc(frame_input: input.FrameInput) -> int {
	return frame_input.current_frame.meta.frame_id
}

bounce_normal :: #force_inline proc(dir: Vector2, normal: Vector2) -> Vector2 {
	surface_perp_projection := math.dot(dir, normal) * normal
	surface_axis := dir - surface_perp_projection

	return surface_axis - surface_perp_projection
}
