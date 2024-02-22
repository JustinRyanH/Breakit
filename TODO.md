# TODO

There are the tasks I want to work on next

## Active

[ ] Event Pool

## Core

[ ] Game Over Scene
[ ] Game Over Scene Win
[ ] Main Menu

## Nice to Haves

[ ] Input Recording, Save to File
[ ] Start Menu
[ ] Start Menu with Keyboard Selectable Options
[ ] Particles on Hit
[ ] Bounce Sounds
[ ] Render Textures for the bricks
[ ] If paddle overlaps ball,
push the ball out, maybe adjust the velocity a bit too
[ ] Make a MicroUI style/atlas editor
[ ] Move main.odin to src
[ ] Propertly close out the debug logs, and compress them
[ ] Crash on hot reload if the memory structure changes

## DONE

[x] Blocks to Break
[x] Fix literal corner case with box collision
[x] MicroUI over Raygui
[x] MVP
[x] Hot Reloading
[x] Steal Zylinski's Leak Detector
[x] Input Recording
[x] Input Playback

## THOUGHTS

Essentially thoughts I have when developing, so I can re-read this and remind
myself of my decisions. Basically my personal Architect of Record

### Thought List

- I want to do a Platform layer like the Handmade Hero,
  what I think I should do is provide an command buffer
  that we build of commands that replicate the
  raylib API (as needed). Then I can swap it out later
  if I have something I like. This existed in the Zig
  version, but also want this for the Odin version
- I want to have a loop system, where I can essentially
  loop my frames on reload and utilize the hot Reloading
  of code to iterate on a bug. The first step will be too
  loop from the beginning over and over, but later I want
  to be able to loop from a give frame. I did manage it in
  my test input debugger, but now I want to use this in the
  game proper.
- **Crash on hot reload if the memory structure changes**
  Write a program that reads through `GameMemory` and
  all of the types below. return Sha of all the types,
  and have a function that returns the sha from the DLL.
  If main.odin sees the sha change just crash the app
  Once future me gets annoyed with a crash I will then
  try to use the playback loop to re-create the memory
- **Refactor the CTX to not be part of game memory**
  The Context from frame is orthogonal from the Context
  Game Memory is the state of the game after the input from the frames
  and this is inserted into the the game.dll every frame. So we shouldn't
  leave this weird dangling context on the memory state
- Why I use Fixed RingBuffer and DataPool over Dynamic Array?
  My hope since it all will be pushed to the Heap in one big data chunk
  it should be MUCH easier to serialize the whole state to a
  file, memory copy, or something else than a dynamic array.
  Note: I've decided to use a ring buffer for a GameEvent because
  I likely will only resolve them at the start of a frame, not at
  the end
- That said I will use dynamic array with temporary allocator
  if make(T, 0, X, context.temp_allocator) at the start of a frames
  but this is because I won't need to save it.
