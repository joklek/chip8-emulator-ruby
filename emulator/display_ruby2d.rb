# frozen_string_literal: true

require 'ruby2d'

module Emulator
  class DisplayRuby2d

    def initialize(title)
      Window.new
      Window.set title: title, resizable: true
    end

    def draw
      Window.update do
        yield
      end
    end

    def draw_buffer(display_buffer)
      Window.clear
      display_buffer.buffer.each.with_index do |pixel, index|
        x = index % 64
        y = index / 64
        if pixel == 0
          Square.new(x: x * 10, y: y * 10, size: 8, color: 'black')
        elsif pixel == 1
          Square.new(x: x * 10, y: y * 10, size: 8, color: 'white')
        else
          raise "Invalid pixel value #{pixel}"
        end
      end
      display_buffer.clear_dirty!
    end

    def show_display
      Window.show
    end
  end
end
