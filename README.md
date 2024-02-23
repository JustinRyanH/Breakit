# Breakit

This is a project to create a full finished Block Breaker game.
Then to go through several iteration of polish. Hopefully,
this will result in lovely little game with depth.

## How to Build

Clone this repository `git clone https://github.com/JustinRyanH/Breakit.git`

`git checkout odin`

install `odin` version from [here](https://odin-lang.org/docs/install/)

install Taskfile from [here](https://taskfile.dev/installation/)

Run `task cmd:setup`. Run the executable from `bin`.

- For Windows: `bin/Breakit.exe`
- For OSX/Linux: `bin/Breakit`

This edition has hot reloads for OSX and Windows (have not tested Linux).

If you run `task cmd:game` tell Tasklist to watch `game/*` and rebuild the DLL

You can run `task cmd:game --watch` to have the effects live load

---
GDD

## Introduction

### Summary Pitch

### Inspiration

### Player Experience

### Platform

The game will target Mac, Windows, Linux, Chrome, and Steamdeck

### Development Software

- Odin
- Raylib
- Asesprites
- Music? TBD

### Genre

Block Breaker

### Target Audience

None. This is an Experiment that 3 people will play on Itch.io

## Concept

## Art

Pixel Art. Maybe initially 4-8 colors pallete.

## Audio

First iteration is likely Kenney assets,
however, future iterations will be me using existing
tools to learn better audio for gamedev.

## Game Experience

### Gameplay Overview

The player controls a **paddle** that they use to launch a
**ball** that collides with terrain above the paddle.

Powerups drop as well as items that increase the code.

Each time the ball bounces on the paddle it increases
the velocity of ball and the paddle.

### UI

- Main Menu
  - Start
  - Highscores
  - Key Mappings
  - Quit
- Game Over
  - Quit
  - Restart

### Controls

Controller, Keyboard


