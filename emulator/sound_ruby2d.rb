# frozen_string_literal: true

require 'ruby2d'

module Emulator
  class SoundRuby2d
    SOUND_PATH = 'assets/beep.mp3'

    def initialize
      @sound = Sound.new(SOUND_PATH)
    rescue StandardError => e
      puts "Could not load sound file '#{SOUND_PATH}'"
      puts e
    end

    def play
      if @sound
        @sound.play

        return
      end

      puts 'beep start'
    end

    def stop
      if @sound
        @sound.stop

        return
      end

      puts 'beep stop'
    end
  end
end
