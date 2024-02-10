# TODO

There are the tasks I want to work on next

## Active

## Core

[ ] Input Recording Test File

## Nice to Haves

[ ] Input Recording, Stream Compress/Decompress
[ ] Start Menu
[ ] Start Menu with Keyboard Selectable Options
[ ] Particles on Hit
[ ] Bounce Sounds
[ ] Render Textures for the bricks
[ ] If paddle overlaps ball,
push the ball out, maybe adjust the velocity a bit too
[ ] Make a MicroUI style/atlas editor

## DONE

[x] MicroUI over Raygui
[x] MVP
[x] Hot Reloading
[x] Steal Zylinski's Leak Detector
[x] Input Recording
[x] Input Playback

## THOUGHTS

- I want to do a Platform layer like the Handmade Hero,
  what I think I should do is provide an command buffer
  that we build of commands that replicate the
  raylib API (as needed). Then I can swap it out later
  if I have something I like. This existed in the Zig
  version, but also want this for the Odin version
