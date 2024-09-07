# frozen_string_literal: true

require_relative 'emulator/emulator'
require_relative 'emulator/display_ruby2d'
require_relative 'emulator/sound_ruby2d'

class RunEmulator
  TICK_PER_SECOND = 700

  KEY_MAP = {
    '1' => 0x1,
    '2' => 0x2,
    '3' => 0x3,
    '4' => 0xC,
    'Q' => 0x4,
    'W' => 0x5,
    'E' => 0x6,
    'R' => 0xD,
    'A' => 0x7,
    'S' => 0x8,
    'D' => 0x9,
    'F' => 0xE,
    'Z' => 0xA,
    'X' => 0x0,
    'C' => 0xB,
    'V' => 0xF,
  }.freeze

  def self.run
    puts 'Welcome to the Emulator'
    file_name = ARGV[0].to_s
    unless file_name
      puts 'Please enter the name of the file you would like to emulate'
      return
    end

    file = File.open(file_name)
    file_data = file.read.bytes
    file.close

    run_file(file_data, file_name)

    puts 'Emulation complete'
  end

  def self.run_file(file_data, file_name)
    emulator = ::Emulator::Emulator.new
    emulator.load_data(file_data)

    display = Emulator::DisplayRuby2d.new(file_name)
    sound = Emulator::SoundRuby2d.new

    display.draw do
      start_time = Time.now
      time_spent = 0.0
      instructions_per_cycle = 0
      until time_spent > (1.0 / display.fps) || instructions_per_cycle > TICK_PER_SECOND / display.fps
        emulator.cycle

        time_spent = Time.now - start_time
        instructions_per_cycle += 1
      end

      display.on_key_press do |key|
        mapped_key = KEY_MAP[key.upcase]
        emulator.pressed_key = mapped_key
      end
      display.on_key_release do |_|
        emulator.pressed_key = nil
      end

      puts "#{instructions_per_cycle} instructions per #{time_spent*1000}ms"
      emulator.decrement_delay_timer
      emulator.decrement_sound_timer

      sound.stop if emulator.sound_timer == 0
      sound.play if emulator.sound_timer != 0
      display.draw_buffer(emulator.display_buffer) if emulator.display_buffer.dirty?
    end

    display.show_display
  end

  run
end
