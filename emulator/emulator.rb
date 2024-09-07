# frozen_string_literal: true

require_relative 'display_buffer'

module Emulator
  class Emulator
    MEMORY_SIZE = 4 * 1024
    FONT_OFFSET = 0x50
    PC_START = 0x200

    attr_reader :memory, :display_buffer, :program_counter, :general_registers, :index_register, :stack, :sound_timer, :delay_timer, :pressed_key

    def initialize
      @program_counter = PC_START
      @index_register = 0
      @stack = []
      @general_registers = Array.new(16, 0)
      @memory = initial_memory
      @display_buffer = DisplayBuffer.new
      @delay_timer = 0
      @sound_timer = 0
      @pressed_key = nil # TODO implement. Also this implementation assumes one keypress at a time
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
    end

    def fetch_opcode
      opcode = @memory[@program_counter] << 8 | @memory[@program_counter + 1]
      @program_counter += 2
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
        @program_counter = @stack.pop
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
          @program_counter += 2
        end
      elsif first_nibble == 6
        @general_registers[second_nibble] = opcode & 0x00FF
      elsif first_nibble == 7
        value = @general_registers[second_nibble] + opcode & 0x00FF
        @general_registers[second_nibble] = value & 0xFF
      elsif first_nibble == 8 && fourth_nibble == 0
        @general_registers[second_nibble] = @general_registers[third_nibble]
      elsif first_nibble == 8 && fourth_nibble == 1
        @general_registers[second_nibble] |= @general_registers[third_nibble]
      elsif first_nibble == 8 && fourth_nibble == 2
        @general_registers[second_nibble] &= @general_registers[third_nibble]
      elsif first_nibble == 8 && fourth_nibble == 3
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
        # @general_registers[second_nibble] = @general_registers[third_nibble]
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
        offset = @general_registers[0]
        @program_counter = address + offset
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

            unless @display_buffer.set_pixel(x + x_coord, y + y_coord, value)
              @general_registers[0xF] = 1
            end
          end
        end
      elsif opcode & 0xF0FF == 0xE09E || opcode & 0xF0FF == 0xE0A1
        variant = opcode & 0x00FF
        key_from_register = @general_registers[second_nibble]

        @program_counter += 2 if (variant == 0x9E && key_from_register == @pressed_key)
        @program_counter += 2 if (variant == 0xA1 && key_from_register != @pressed_key)
      elsif opcode & 0xF0FF == 0xF00A
        if @pressed_key
          @general_registers[second_nibble] = @pressed_key
        else
          puts "Waiting for keypress"
          @program_counter -= 2
        end
      elsif opcode & 0xF0FF == 0xF007
        @general_registers[second_nibble] = @delay_timer
      elsif opcode & 0xF0FF == 0xF015
        @delay_timer = @general_registers[second_nibble]
      elsif opcode & 0xF0FF == 0xF018
        @sound_timer = @general_registers[second_nibble]
      elsif opcode & 0xF0FF == 0xF01E
        @index_register = (@index_register + @general_registers[second_nibble]) & 0xFFFF
      elsif opcode & 0xF0FF == 0xF029
        @index_register = FONT_OFFSET + (second_nibble & 0x000F) * 5
      elsif opcode & 0xF0FF == 0xF033
        value = @general_registers[second_nibble]

        @memory[@index_register] = value / 100
        @memory[@index_register + 1] = (value / 10) % 10
        @memory[@index_register + 2] = value % 10
      elsif opcode & 0xF0FF == 0xF055
        for i in 0..second_nibble
          @memory[@index_register + i] = @general_registers[i]
        end
      elsif opcode & 0xF0FF == 0xF065
        for i in 0..second_nibble
          @general_registers[i] = @memory[@index_register + i]
        end
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

    def pressed_key=(key)
      @pressed_key = key
    end

    def delay_timer=(key)
      puts 'this should not be called in production code'
      @delay_timer = key
    end

    def index_register=(key)
      puts 'this should not be called in production code'
      @index_register = key
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
