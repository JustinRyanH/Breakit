# TODO

There are the tasks I want to work on next

## Active

[ ] Recording, Pause/Resume in Main Game
[ ] Open up a menu, select a previous frame, and
[ ] Playback From start of Main Game
[ ]

## Core

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
[ ] Move main.odin to src

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
- I want to have a loop system, where I can essentially
  loop my frames on reload and utilize the hot Reloading
  of code to iterate on a bug. The first step will be too
  loop from the beginning over and over, but later I want
  to be able to loop from a give frame. I did manage it in
  my test input debugger, but now I want to use this in the
  game proper.
