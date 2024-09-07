# frozen_string_literal: true

require 'ruby2d'

module Emulator
  class DisplayRuby2d

    def initialize(title)
      Window.set title: title, resizable: true

      @pixels = {}
      (0..63).each do |x|
        @pixels[x] = {}
        (0..31).each do |y|
          @pixels[x][y] = Square.new(x: x * 10, y: y * 10, size: 8, color: 'black')
        end
      end
    end

    def draw
      Window.update do
        yield
      end
    end

    def on_key_press
      Window.on :key_down do |event|
        yield(event.key)
      end
    end

    def on_key_release
      Window.on :key_up do |event|
        yield(event.key)
      end
    end

    def draw_buffer(display_buffer)
      display_buffer.buffer.each.with_index do |pixel, index|
        x = index % 64
        y = index / 64
        if pixel == 0
          @pixels[x][y].color = 'black'
        elsif pixel == 1
          @pixels[x][y].color = 'white'
        else
          raise "Invalid pixel value #{pixel}"
        end
      end
      puts "fps #{Window.fps} and fps cap #{Window.fps_cap}"
      display_buffer.clear_dirty!
    end

    def show_display
      Window.show
    end

    def fps
      Window.fps
    end
  end
end
