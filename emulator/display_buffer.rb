# frozen_string_literal: true

module Emulator
  class DisplayBuffer

    attr_reader :buffer

    def initialize
      @buffer = Array.new(64 * 32, 0)
      @is_dirty = false
    end

    def reset
      for i in 0..@buffer.length - 1
        @buffer[i] = 0
      end

      @is_dirty = true
    end

    def set_pixel(x, y, value)
      return false if x > 63 || y > 31 || x < 0 || y < 0

      old_value = @buffer[y * 64 + x]
      return false if old_value == value

      @buffer[y * 64 + x] = value # TODO: Figure out what's the correct behavior here

      @is_dirty = true
    end

    def dirty?
      @is_dirty
    end

    def clear_dirty!
      @is_dirty = false
    end
  end
end
