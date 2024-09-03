# frozen_string_literal: true

require_relative 'display_buffer'

module Emulator
  class Emulator
    MEMORY_SIZE = 4 * 1024
    PC_START = 0x200

    attr_reader :memory, :display_buffer, :program_counter, :general_registers, :index_register

    def initialize
      @program_counter = PC_START
      @index_register = 0
      @stack = []
      @general_registers = Array.new(16, 0)
      @memory = initial_memory
      @display_buffer = DisplayBuffer.new
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
      elsif first_nibble == 1
        @program_counter = opcode & 0x0FFF
      elsif first_nibble == 6
        @general_registers[second_nibble] = opcode & 0x00FF
      elsif first_nibble == 7
        @general_registers[second_nibble] += opcode & 0x00FF
      elsif first_nibble == 0x000A
        @index_register = opcode & 0x0FFF
      elsif first_nibble == 0x000D
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
      else
        raise "Unknown opcode: #{opcode}"
      end
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

      FONTS.each.with_index { |byte, index| initial_memory[0x50 + index] = byte }

      initial_memory
    end
  end
end
