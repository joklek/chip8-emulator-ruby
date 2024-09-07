# frozen_string_literal: true

require_relative 'emulator/emulator'
require_relative 'emulator/display_ruby2d'
require_relative 'emulator/sound_ruby2d'

class RunEmulator
  TICK_PER_SECOND = 700

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
      until time_spent > (1.0 / 60)
        emulator.cycle
        time_spent = Time.now - start_time
        # sleep 1.0 / TICK_PER_SECOND
      end

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
