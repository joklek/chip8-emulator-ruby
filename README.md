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
  - [x] Configurable quirks
    - Only configurable in code for now
  - [ ] Chip-8 keypad input
    - Something's not 100% correct with the key up/down handling
    - Multiple keys pressed at the same time are not handled correctly
  - Passes [Timendus tests](https://github.com/Timendus/chip8-test-suite)
    - [x] 1-chip8-logo.ch8
    - [x] 2-ibm-logo.ch8
    - [x] 3-corax+.ch8
    - [x] 4-flags.ch8
    - [ ] 5-quirks.ch8
      - Fails `Display Wait` test
      - Default config fails `vf_reset`, needs quirk `vf_reset: true` to pass
    - [ ] 6-keypad.ch8
      - Fails `Fx0A GETKEY` with 'Not Released' error
