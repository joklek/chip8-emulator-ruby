# joklek's Chip-8 Emulator

![Emulator running `heart_monitor.ch8`](emulator.png)

A basic [Chip-8](https://en.wikipedia.org/wiki/CHIP-8) emulator written in Ruby. Using Ruby2D for graphics, audio and input handling.

## Requirements

You must have Ruby installed.

If you want audio to work, add a beeping sound asset to `assets/beep.mp3`

Before running the emulator, install the required gems by running `bin/bundle install`.

## Usage

```bash
ruby run_emulator.rb <path_to_rom>
```

## Functionality

  - [x] Chip-8 black and white graphics
  - [x] Chip-8 sound
  - [x] Chip-8 timers
  - [x] All Chip-8 opcodes implemented and working
  - [x] Keypad working
    - [x] Multiple keys pressed at the same time available
    - Controlled with the following keys:
      - `1 2 3 4`
      - `Q W E R`
      - `A S D F`
      - `Z X C V`
  - [x] Configurable quirks
    - Only configurable in code for now
  - Passes [Timendus tests](https://github.com/Timendus/chip8-test-suite)
    - [x] 1-chip8-logo.ch8
    - [x] 2-ibm-logo.ch8
    - [x] 3-corax+.ch8
    - [x] 4-flags.ch8
    - [x] 5-quirks.ch8
      - Default config fails `vf_reset`, needs quirk `vf_reset: true` to pass
    - [x] 6-keypad.ch8
