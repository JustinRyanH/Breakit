# TODO

There are the tasks I want to work on next

## Active

[ ] Game Over Scene

## Core

[ ] Game Over Scene Win
[ ] Main Menu

## Nice to Haves

[ ] Steal Small_Array `as_slice` for DataPool
  I don't think I should do that for RingBuffer
[ ] Actually Finish the loop for Playback
[ ] Input Recording, Save to File
[ ] Start Menu
[ ] Start Menu with Keyboard Selectable Options
[ ] Particles on Hit
[ ] Bounce Sounds
[ ] Render Textures for the bricks
[ ] Make a MicroUI style/atlas editor
[ ] Move main.odin to src
[ ] Propertly close out the debug logs, and compress them
[ ] Crash on hot reload if the memory structure changes

## DONE

[x] Push Ball out if overlaps
[x] Event Pool
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
  **Update: 2024-02-22** Yeah doesn't seem necessary at
  this stage.
- I want to have a loop system, where I can essentially
  loop my frames on reload and utilize the hot Reloading
  of code to iterate on a bug. The first step will be too
  loop from the beginning over and over, but later I want
  to be able to loop from a give frame. I did manage it in
  my test input debugger, but now I want to use this in the
  game proper.
  **Update: 2024-02-22**: I did end up yakshaving the
  crap out of this in a separate exe. I ended up throwing it away
  as well as the game to and just ended storing them in memory. I
  will go back to streaming to file later. I think my original
  problem is I'm not smart enough to manage dynamic memory in the
  game struct. So I ended up going with "DataPool"
- **Crash on hot reload if the memory structure changes**
  Write a program that reads through `GameMemory` and
  all of the types below. return SHA of all the types,
  and have a function that returns the SHA from the DLL.
  If main.odin sees the sha change just crash the app
  Once future me gets annoyed with a crash I will then
  try to use the playback loop to re-create the memory
  **Update: 2024-02-22:** I still think this is a good idea,
  but I will likely just fast replay to current frame. But
  I don't know if I should do that because there isn't a way
  to automatically validate the data if the memory structure has
  changed.
- **Refactor the CTX to not be part of game memory**
  The Context from frame is orthogonal from the Context
  Game Memory is the state of the game after the input from the frames
  and this is inserted into the the game.dll every frame. So we shouldn't
  leave this weird dangling context on the memory state
  **Update: 2024-02-22:** This has been big success. I just update the
  context every frame. I also did this with the frame_input since
  that too comes from the platform every frame.
- Why I use Fixed RingBuffer and DataPool over Dynamic Array?
  My hope since it all will be pushed to the Heap in one big data chunk
  it should be MUCH easier to serialize the whole state to a
  file, memory copy, or something else than a dynamic array.
  Note: I've decided to use a ring buffer for a GameEvent because
  I likely will only resolve them at the start of a frame, not at
  the end. If I want to save our a frame and replay it or test it
  I need to have this state between
- That said I will use dynamic array with temporary allocator
  if make(T, 0, X, context.temp_allocator) at the start of a frames
  but this is because I won't need to save it.
