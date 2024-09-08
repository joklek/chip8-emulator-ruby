# frozen_string_literal: true

module Emulator
  class DisplayBuffer

    attr_reader :buffer

    def initialize(quirks_config = {})
      @buffer = Array.new(64 * 32, 0)
      @is_dirty = false
      @quirks_config = quirks_config
    end

    def reset
      for i in 0..@buffer.length - 1
        @buffer[i] = 0
      end

      @is_dirty = true
    end

    def set_pixel(x, y, value)
      return if x >= 64 && @quirks_config[:clipping]
      return if y >= 32 && @quirks_config[:clipping]
      x = x % 64
      y = y % 32

      old_value = @buffer[y * 64 + x]
      new_value = old_value ^ value
      return if old_value == new_value

      @buffer[y * 64 + x] = new_value
      @is_dirty = true

      new_value == 0 && old_value == 1
    end

    def dirty?
      @is_dirty
    end

    def clear_dirty!
      @is_dirty = false
    end
  end
end
