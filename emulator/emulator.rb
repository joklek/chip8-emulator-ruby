# frozen_string_literal: true

require_relative 'display_buffer'

module Emulator
  class Emulator
    MEMORY_SIZE = 4 * 1024
    FONT_OFFSET = 0x50
    PC_START = 0x200

    attr_reader :memory, :display_buffer, :program_counter, :general_registers, :index_register, :stack, :sound_timer, :delay_timer, :pressed_key

    def initialize(quirks_config = {})
      @program_counter = PC_START
      @index_register = 0
      @stack = []
      @general_registers = Array.new(16, 0)
      @memory = initial_memory
      @display_buffer = DisplayBuffer.new(quirks_config)
      @delay_timer = 0
      @sound_timer = 0
      @pressed_keys = {}
      @pressed_keys_last = {}
      @quirks_config = quirks_config
    end

    def load_data(data)
      raise "Data is not an array" unless data.is_a?(Array)
      raise "Data too large for memory" if data.length > MEMORY_SIZE
      raise "Array contains non-byte data" if data.any? { |byte| !byte.is_a?(Integer) || byte < 0 || byte > 255 }

      data.each.with_index do |byte, index|
        @memory[PC_START + index] = byte
      end
    end

    def cycle
      opcode = fetch_opcode
      execute_opcode(opcode)
      @pressed_keys_last = @pressed_keys.dup
    end

    def fetch_opcode
      opcode = @memory[@program_counter] << 8 | @memory[@program_counter + 1]
      @program_counter = (@program_counter + 2) & 0xFFFF
      opcode
    end

    def execute_opcode(opcode)
      first_nibble = (opcode >> 12)
      second_nibble = (opcode >> 8) & 0x000F
      third_nibble = (opcode >> 4) & 0x000F
      fourth_nibble = opcode & 0x000F

      if opcode == 0x00E0
        @display_buffer.reset
      elsif opcode == 0x00EE
        @program_counter = @stack.pop & 0xFFFF
      elsif first_nibble == 1
        @program_counter = opcode & 0x0FFF
      elsif first_nibble == 2
        @stack.push(@program_counter)
        @program_counter = opcode & 0x0FFF
      elsif [3, 4, 5, 9].include?(first_nibble)
        expected_value = third_nibble << 4
        expected_value |= [3, 4].include?(first_nibble) ? fourth_nibble : 0

        real_value = @general_registers[second_nibble]
        real_value_2 = @general_registers[third_nibble]

        if (first_nibble == 3 && real_value == expected_value) ||
          (first_nibble == 4 && real_value != expected_value) ||
          (first_nibble == 5 && real_value == real_value_2) ||
          (first_nibble == 9 && real_value != real_value_2)
          @program_counter = (@program_counter + 2 ) & 0xFFFF
        end
      elsif first_nibble == 6
        @general_registers[second_nibble] = opcode & 0xFF
      elsif first_nibble == 7
        value = @general_registers[second_nibble] + (opcode & 0xFF)
        @general_registers[second_nibble] = value & 0xFF
      elsif first_nibble == 8 && fourth_nibble == 0
        @general_registers[second_nibble] = @general_registers[third_nibble]
      elsif first_nibble == 8 && fourth_nibble == 1
        @general_registers[0xF] = 0 if @quirks_config[:vf_reset]
        @general_registers[second_nibble] |= @general_registers[third_nibble]
      elsif first_nibble == 8 && fourth_nibble == 2
        @general_registers[0xF] = 0 if @quirks_config[:vf_reset]
        @general_registers[second_nibble] &= @general_registers[third_nibble]
      elsif first_nibble == 8 && fourth_nibble == 3
        @general_registers[0xF] = 0 if @quirks_config[:vf_reset]
        @general_registers[second_nibble] ^= @general_registers[third_nibble]
      elsif first_nibble == 8 && fourth_nibble == 4
        @general_registers[second_nibble] += @general_registers[third_nibble]
        @general_registers[0xF] = @general_registers[second_nibble] > 0xFF ? 1 : 0
        @general_registers[second_nibble] &= 0xFF
      elsif first_nibble == 8 && [5, 7].include?(fourth_nibble)
        minuend = fourth_nibble == 5 ? @general_registers[second_nibble] : @general_registers[third_nibble]
        subtrahend = fourth_nibble == 5 ? @general_registers[third_nibble] : @general_registers[second_nibble]

        @general_registers[second_nibble] = (minuend - subtrahend) & 0xFF
        @general_registers[0xF] = minuend >= subtrahend ? 1 : 0
      elsif first_nibble == 8 && [6, 0xE].include?(fourth_nibble)
        @general_registers[second_nibble] = @general_registers[third_nibble] unless @quirks_config[:shifting]
        value = @general_registers[second_nibble]

        if fourth_nibble == 6
          @general_registers[second_nibble] = value >> 1
          @general_registers[0xF] = value & 0x1
        else
          @general_registers[second_nibble] = (value << 1) & 0xFF
          @general_registers[0xF] = value >> 7
        end
      elsif first_nibble == 0xA
        @index_register = opcode & 0x0FFF
      elsif first_nibble == 0xB
        address = opcode & 0x0FFF
        offset = @quirks_config[:jumping] ? @general_registers[second_nibble] : @general_registers[0]
        @program_counter = (address + offset) & 0xFFFF
      elsif first_nibble == 0xC
        @general_registers[second_nibble] = rand(0x00FF) & (opcode & 0x00FF)
      elsif first_nibble == 0xD
        x = @general_registers[second_nibble] % 64
        y = @general_registers[third_nibble] % 32
        height = fourth_nibble
        @general_registers[0xF] = 0

        for y_coord in 0..(height - 1)
          byte_value = @memory[@index_register + y_coord]

          for x_coord in 0..7
            value = (byte_value >> (7 - x_coord)) & 0x1

            if @display_buffer.set_pixel(x + x_coord, y + y_coord, value)
              @general_registers[0xF] = 1
            end
          end
        end
      elsif opcode & 0xF0FF == 0xE09E || opcode & 0xF0FF == 0xE0A1
        variant = opcode & 0x00FF
        key_from_register = @general_registers[second_nibble]

        @program_counter = (@program_counter + 2) & 0xFFFF if (variant == 0x9E && @pressed_keys[key_from_register])
        @program_counter = (@program_counter + 2) & 0xFFFF if (variant == 0xA1 && !@pressed_keys[key_from_register])
      elsif opcode & 0xF0FF == 0xF00A
        key_released = false
        @pressed_keys_last.keys.each do |key|
          unless @pressed_keys[key]
            @general_registers[second_nibble] = key
            key_released = true
            break
          end
        end
        unless key_released
          puts "Waiting for keypress"
          @program_counter = (@program_counter - 2) & 0xFFFF
        end
      elsif opcode & 0xF0FF == 0xF007
        @general_registers[second_nibble] = @delay_timer & 0xFF
      elsif opcode & 0xF0FF == 0xF015
        @delay_timer = @general_registers[second_nibble]
      elsif opcode & 0xF0FF == 0xF018
        @sound_timer = @general_registers[second_nibble]
      elsif opcode & 0xF0FF == 0xF01E
        @index_register = (@index_register + @general_registers[second_nibble]) & 0xFFFF
      elsif opcode & 0xF0FF == 0xF029
        @index_register = (FONT_OFFSET + (@general_registers[second_nibble] & 0x000F) * 5) & 0xFFFF
      elsif opcode & 0xF0FF == 0xF033
        value = @general_registers[second_nibble]

        @memory[@index_register] = value / 100
        @memory[@index_register + 1] = (value / 10) % 10
        @memory[@index_register + 2] = value % 10
      elsif opcode & 0xF0FF == 0xF055
        for i in 0..second_nibble
          @memory[@index_register + i] = @general_registers[i]
        end
        @index_register = (@index_register + second_nibble + 1) & 0xFFFF if @quirks_config[:memory]
      elsif opcode & 0xF0FF == 0xF065
        for i in 0..second_nibble
          @general_registers[i] = @memory[@index_register + i]
        end
        @index_register = (@index_register + second_nibble + 1) & 0xFFFF if @quirks_config[:memory]
      else
        puts "Unknown opcode: 0x#{opcode.to_s(16)}"
      end
    end

    def decrement_delay_timer
      return unless @delay_timer > 0

      @delay_timer -= 1
    end

    def decrement_sound_timer
      return unless @sound_timer > 0

      @sound_timer -= 1
    end

    def key_pressed!(key)
      @pressed_keys[key] = true
    end

    def key_released!(key)
      @pressed_keys.delete(key)
    end

    def delay_timer=(key)
      puts 'this should not be called in production code'
      @delay_timer = key
    end

    def index_register=(key)
      puts 'this should not be called in production code'
      @index_register = key
    end

    def pressed_keys_last=(keys)
      puts 'this should not be called in production code'
      @pressed_keys_last = keys
    end

    def running?
      true
    end

    private

    FONTS = [
      0xF0, 0x90, 0x90, 0x90, 0xF0, # 0
      0x20, 0x60, 0x20, 0x20, 0x70, # 1
      0xF0, 0x10, 0xF0, 0x80, 0xF0, # 2
      0xF0, 0x10, 0xF0, 0x10, 0xF0, # 3
      0x90, 0x90, 0xF0, 0x10, 0x10, # 4
      0xF0, 0x80, 0xF0, 0x10, 0xF0, # 5
      0xF0, 0x80, 0xF0, 0x90, 0xF0, # 6
      0xF0, 0x10, 0x20, 0x40, 0x40, # 7
      0xF0, 0x90, 0xF0, 0x90, 0xF0, # 8
      0xF0, 0x90, 0xF0, 0x10, 0xF0, # 9
      0xF0, 0x90, 0xF0, 0x90, 0x90, # A
      0xE0, 0x90, 0xE0, 0x90, 0xE0, # B
      0xF0, 0x80, 0x80, 0x80, 0xF0, # C
      0xE0, 0x90, 0x90, 0x90, 0xE0, # D
      0xF0, 0x80, 0xF0, 0x80, 0xF0, # E
      0xF0, 0x80, 0xF0, 0x80, 0x80  # F
    ].freeze

    def initial_memory
      initial_memory = Array.new(MEMORY_SIZE, 0)

      FONTS.each.with_index { |byte, index| initial_memory[FONT_OFFSET + index] = byte }

      initial_memory
    end
  end
end
