# TODO

There are the tasks I want to work on next

## Active

[] MVP

## Core

[ ] Start Menu
[ ] Start Menu with Keyboard Selectable Options
[ ] Bounce Sounds
[ ] Particles on Hit
[ ] Render Textures for the bricks
[ ] IMGUI over Raygui

## Nice to Haves

[ ] Input Recording
[ ] Input Recording Test File
[ ] Input Playback
[ ] Input Recording, Hash the InputFrame struct.
Create an update path as we change InputFrame
[ ] Input Recording, Stream Compress/Decompress
[ ] Swap out the Raylib platform for mach

## DONE

[x] Hot Reloading

## THOUGHTS

- I want to do a Platform layer like the Handmade Hero,
  what I think I should do is provide an command buffer
  that we build of commands that replicate the
  raylib API (as needed). Then I can swap it out later
  if I have something I like. This existed in the Zig
  version, but also want this for the Odin version
