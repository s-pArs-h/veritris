# Veritris

A Tetris game implemented entirely in hardware: Verilog game logic and a VGA
renderer running on a Digilent Nexys A7 (Artix-7) FPGA. Team project by
Rachit Sinha and Sparsh Kumar.

Game state lives in registers and is updated by a finite-state machine;
collision checks over the 4x4 piece box happen in parallel in one cycle; the
renderer turns the board into pixels on the fly, with no frame buffer.

## Demo

https://github.com/user-attachments/assets/f010f0dc-0b65-4614-8cdf-9e57bb16b724

## Features

* 10 x 20 board, all seven tetrominoes with rotation, 7 colours
* Pseudorandom piece selection (8-bit LFSR)
* Gravity (one row per second), left/right movement, rotation
* Collision detection against walls, floor and the stack, for every move
* Landing, full-row detection and clearing with the rows above shifting down
  (several rows per landing)
* Score (rows cleared, BCD) on the seven-segment display
* Start screen, and game over when a new piece cannot enter (board turns red)

Not implemented: 7-bag randomiser, next-piece preview, hold, soft/hard drop,
levels.

| Control | Action |
|---|---|
| BTNL / BTNR | move left / right |
| BTNU | rotate |
| any of BTNL / BTNR / BTNU | start from the start screen |
| BTNC | reset / restart |

## Architecture

```
CLK100MHZ -> MMCM -> 25 MHz pixel clock -----------------------------------+
BTNC ------> reset synchroniser -> reset (async assert, sync release)      |
BTNL/R/U --> 2-flop sync -> debounce -> one-cycle press pulse --+          |
gravity counter (1 s) ------------------------------------------+          |
                                                                v          |
 vga_controller: 800 x 525 counters  --x, y-->  tetris_engine              |
   hsync / vsync (registered)                    game FSM, 200-cell grid,  |
                                                 collision, line clear,    |
                                                 renderer (registered RGB) |
                                                         |                 |
   VGA_R/G/B (4 bit each) <------------------------------+                 |
   seven_seg_driver: score -> multiplexed 4-digit display <----------------+
```

**Game FSM** (`tetris_engine.v`): START_SCREEN -> SPAWN -> WAIT -> CHECK ->
(move accepted, or LAND) -> LINE_CHECK <-> LINE_SHIFT -> SPAWN, and
GAME_OVER when a piece collides while still above the board. Every move is
first tried on a "test" position; the collision vector compares the piece's
4x4 mask with the board cells under it in a single cycle.

**Rendering**: the renderer maps the current pixel to a board cell and picks
the colour of the falling piece, the stored cell, the board background or the
border. The colour is registered, and the VGA controller registers hsync,
vsync and the visible-area flag so all of them reach the pins on the same
cycle.

**Clocking and reset**: the 25 MHz pixel clock comes from the MMCM through a
global buffer (`clock_gen.v`). Reset is released synchronously
(`reset_sync.v`), and buttons pass through a two-flop synchroniser before the
debouncer, because they are asynchronous to the clock.

## Verification

`sim/tb_top.v` runs the whole design (Verilator, or Icarus Verilog, which is
much slower) and checks:

* VGA timing: hsync every 800 pixels with a 96-pixel pulse, vsync every 525
  lines with a 2-line pulse
* game flow: a button press starts the game, pieces fall and land, and with no
  input the stack reaches the top and the game ends
* line clearing: a full bottom row is cleared when the next piece lands, the
  row above shifts down, the score becomes 1 and the display shows "1"

The design is lint-clean under Verilator `-Wall`.

## Building

```
make lint      # Verilator -Wall
make sim       # Verilator testbench (make sim-icarus for Icarus Verilog)
```

Vivado: create a project for `xc7a100tcsg324-1`, add all `*.v` files in the
repository root and `constraints/nexys_a7.xdc` (pins from Digilent's master
XDC), set `nexys_tetris_top` as top and generate the bitstream.

## Files

```
nexys_tetris_top.v   top level: clocking, reset, buttons, gravity, I/O
tetris_engine.v      game FSM, board, collision, line clear, renderer
vga_controller.v     640x480 @ 60 Hz timing
seven_seg_driver.v   multiplexed BCD score display
debouncer.v          synchroniser + debounce + press pulse
clock_gen.v          MMCM 100 -> 25 MHz
reset_sync.v         reset synchroniser
constraints/         Nexys A7 pin constraints
sim/tb_top.v         system testbench
```

## Changes in this revision

* Added the missing seven-segment driver (the design did not build without it)
* Replaced the flip-flop clock divider with an MMCM-generated clock
* Added a reset synchroniser and button synchronisers
* VGA sync outputs registered and aligned with the renderer's registered colour
* Exact one-second gravity period; decimal points driven off
* Added `.v` extensions, Nexys A7 constraints, a system testbench, a Makefile
  and CI; fixed Verilator lint warnings
