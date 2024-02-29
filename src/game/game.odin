package game

import sa "core:container/small_array"
import "core:fmt"
import "core:hash"
import "core:io"
import math "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "core:strings"

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

DestroyBrickEvent :: struct {
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

RestartEvent :: struct {}

GameEvent :: union {
	DestroyBrickEvent,
	BeginFreeMovement,
	BallDeathEvent,
	RestartEvent,
}


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

GameFonts :: struct {
	kenney_block:  Font,
	kenney_future: Font,
}

GameMemory :: struct {
	scene_width:  f32,
	scene_height: f32,

	// Game Entities
	stage:        Stages,

	// Game Entities
	entities:     DataPool(512, Entity, EntityHandle),
	event_queue:  RingBuffer(256, GameEvent),
	fonts:        GameFonts,
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
	// We're doing hard reset. This will clear out any lingering handles between frame
	g_mem^ = GameMemory{}

	g_mem.scene_width = 800
	g_mem.scene_height = 600

	draw_cmds := ctx.draw_cmds
	g_mem.fonts.kenney_block = draw_cmds.text.load_font("assets/fonts/Kenney Blocks.ttf")
	g_mem.fonts.kenney_future = draw_cmds.text.load_font("assets/fonts/Kenney Future.ttf")

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

		lp, is_loop := &ctx.playback.(input.Loop)
		if is_loop {
			mu.window(mui_ctx, "Replay Controls", {500, 100, 300, 175}, {.NO_CLOSE})
			mu.layout_row(mui_ctx, {-1})
			frame := cast(mu.Real)lp.index
			mu.slider(
				mui_ctx,
				&frame,
				0,
				cast(mu.Real)lp.last_frame_index,
				1,
				"%.0f",
				{.NO_INTERACT},
			)
			mu.layout_row(mui_ctx, {100, 100})
			mu.label(mui_ctx, fmt.tprintf("Start: %d", lp.start_index))
			mu.label(mui_ctx, fmt.tprintf("End: %d", lp.end_index))
		}

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
			mu.slider(mui_ctx, &target_frame, 0, cast(mu.Real)rp.last_frame_index, 1, "%.0f")

			mu.layout_row(mui_ctx, {80, 75, 75})
			@(static)
			start_frame: mu.Real
			@(static)
			end_frame: mu.Real

			if (end_frame == 0) {
				end_frame = cast(mu.Real)rp.last_frame_index - 1
			}

			res := mu.button(mui_ctx, "Loop Between")
			if .SUBMIT in res {
				append(&ctx.events, BeginLoop{cast(int)start_frame, cast(int)end_frame})
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
		stage_lose_draw(s)
	case StageWin:
		stage_win_draw(s)
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

@(export)
game_save_to_stream :: proc(stream: io.Stream) -> io.Error {
	_, err := io.write_ptr(stream, g_mem, size_of(GameMemory))
	return err
}

@(export)
game_load_from_stream :: proc(stream: io.Stream) -> io.Error {
	_, err := io.read_ptr(stream, g_mem, size_of(GameMemory))
	return err
}

@(export)
game_mem_size :: proc() -> int {
	return size_of(GameMemory)
}

update_gameplay :: proc(frame_input: input.FrameInput) {

	dt := input.frame_query_delta(frame_input)
	g_input = frame_input


	for event in ring_buffer_pop(&g_mem.event_queue) {
		switch evt in event {
		case BallDeathEvent:
			stage, is_stage := &g_mem.stage.(StageMain)
			if is_stage {
				if (stage.lives > 0) {
					stage.lives -= 1
					ball := get_ball(&g_mem.entities, stage.ball)
					ball.state = LockedToEntity{stage.paddle, Vector2{0, -20}}
				} else {
					switch_stage(StageLose{})
				}
			}
		case DestroyBrickEvent:
			removed := data_pool_remove(&g_mem.entities, evt.handle)
			if !removed {
				fmt.println("Failed to remove brick at handle", evt)
			}
			stage, is_stage := &g_mem.stage.(StageMain)
			if is_stage {
				stage.bricks_left -= 1
				if (stage.bricks_left == 0) {
					switch_stage(StageWin{})
				}
			}


		case BeginFreeMovement:
			ball := get_ball(&g_mem.entities, evt.ball_handle)
			ball.state = FreeMovement{evt.direction, evt.speed}
		case RestartEvent:
			switch_stage(StageMain{})
		}
	}

	switch stage in &g_mem.stage {
	case StageMain:
		stage_main_update(&stage, frame_input)
	case StageWin:
		stage_win_update(&stage, frame_input)
	case StageLose:
		stage_lose_update(&stage, frame_input)
	}

}

switch_stage :: proc(next_stage: Stages) {
	cleanup_previous_stage(&g_mem.stage)
	setup_next_stage(next_stage)
}

setup_next_stage :: proc(stage: Stages) {
	g_mem.stage = stage
	switch s in &g_mem.stage {
	case StageMain:
		stage_main_setup(&s)
	case StageWin:
		stage_win_setup(&s)
	case StageLose:
		stage_lose_setup(&s)
	}
}

cleanup_previous_stage :: proc(stage: ^Stages) {
	switch s in stage {
	case StageMain:
		data_pool_reset(&g_mem.entities)
	case StageWin:
		stage_win_cleanup(&s)
	case StageLose:
		stage_lose_cleanup(&s)
	}
}

get_frame_id :: proc(frame_input: input.FrameInput) -> int {
	return frame_input.current_frame.meta.frame_id
}

bounce_normal :: #force_inline proc(dir: Vector2, normal: Vector2) -> Vector2 {
	surface_perp_projection := math.dot(dir, normal) * normal
	surface_axis := dir - surface_perp_projection

	return surface_axis - surface_perp_projection
}

generate_u64_from_string :: proc(s: string) -> u64 {
	return hash.murmur64b(transmute([]u8)s)
}


generate_u64_from_cstring :: proc(cs: cstring) -> u64 {
	s := strings.clone_from_cstring(cs, context.temp_allocator)
	return hash.murmur64b(transmute([]u8)s)
}
