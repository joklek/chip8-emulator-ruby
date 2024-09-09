# frozen_string_literal: true

require 'emulator'

RSpec.describe Emulator::Emulator do
  let(:emulator) { described_class.new(quirks) }
  let(:quirks) { {} }

  GENERAL_REGISTER_INDEX = (0..0x00F)

  it 'test contains all general indices' do
    expect(GENERAL_REGISTER_INDEX.to_a.size).to eq(16)
  end

  describe '#initialize' do
    subject { emulator }

    it 'has fonts in memory' do
      expect(subject.memory[0x50..(0x50 + Emulator::Emulator::FONTS.size - 1)]).to eq(Emulator::Emulator::FONTS)
    end
  end

  describe '#load_data' do
    subject { emulator.load_data(data) }

    let(:data) { [1] }

    it 'loads data into memory' do
      subject
      expect(emulator.memory[0x200..emulator.memory.size]).to start_with(data)
    end

    context 'when data is not an array' do
      let(:data) { 'not an array' }

      it 'raises an error' do
        expect { subject }.to raise_error('Data is not an array')
      end
    end

    context 'when data is too large for memory' do
      let(:data) { Array.new(Emulator::Emulator::MEMORY_SIZE + 1, 0) }

      it 'raises an error' do
        expect { subject }.to raise_error('Data too large for memory')
      end
    end

    context 'when array contains non-byte data' do
      let(:data) { ['256'] }

      it 'raises an error' do
        expect { subject }.to raise_error('Array contains non-byte data')
      end
    end

    context 'when array integer but not byte' do
      let(:data) { [256] }

      it 'raises an error' do
        expect { subject }.to raise_error('Array contains non-byte data')
      end
    end
  end

  describe '#fetch_opcode' do
    subject do
      emulator.load_data(data)
      emulator.fetch_opcode
    end

    let(:data) { [1, 2] }

    it 'returns the opcode' do
      expect(subject).to eq(0x0102)
    end
  end

  describe '#execute_opcode' do
    subject { emulator.execute_opcode(opcode) }

    describe '0x00E0' do
      let(:opcode) { 0x00E0 }

      before { emulator.display_buffer.set_pixel(12, 13, 1) }

      it 'resets the display buffer' do
        expect(emulator.display_buffer.buffer[12 + 13 * 64]).to eq(1)

        subject

        expect(emulator.display_buffer.buffer).to all(be_zero)
      end
    end

    describe '0x00EE' do
      let(:opcode) { 0x00EE }
      let(:address_in_stack) { 0x1234 }

      before do
        emulator.stack.push(0xFFFF)
        emulator.stack.push(0xFFFF)
        emulator.stack.push(address_in_stack)
      end

      it 'sets PC to address from stack' do
        subject

        expect(emulator.program_counter).to eq(address_in_stack)
      end
    end

    describe '0x1XXX' do
      let(:opcode) { 0x1ABC }

      it 'set the program counter' do
        subject

        expect(emulator.program_counter).to eq(0x0ABC)
      end
    end

    describe '0x2XXX' do
      let(:opcode) { 0x2ABC }

      it 'set the program counter to given address' do
        subject

        expect(emulator.program_counter).to eq(0x0ABC)
      end

      it 'adds current address to stack' do
        subject

        expect(emulator.stack.last).to eq(0x200)
      end
    end

    describe '0x3XNN' do
      let(:opcode) { 0x31AB }

      before { emulator.general_registers[1] = 0xAB }

      it 'skips next instruction if register value equals to NN' do
        expect{ subject }.to change{ emulator.program_counter }.by(2)
      end

      context 'when register value does not equal to NN' do
        before { emulator.general_registers[1] = 0xAC }

        it 'does not skip next instruction' do
          expect{ subject }.not_to change{ emulator.program_counter }
        end
      end
    end

    describe '0x4XNN' do
      let(:opcode) { 0x41AB }

      before { emulator.general_registers[1] = 0xAC }

      it 'skips next instruction if register value does not equal to NN' do
        expect{ subject }.to change{ emulator.program_counter }.by(2)
      end

      context 'when register value is equal to NN' do
        before { emulator.general_registers[1] = 0xAB }

        it 'does not skip next instruction' do
          expect{ subject }.not_to change{ emulator.program_counter }
        end
      end
    end

    describe '0x5XY0' do
      let(:opcode) { 0x51A0 }

      before do
        emulator.general_registers[0x1] = 0xAC
        emulator.general_registers[0xA] = 0xAC
      end

      it 'skips next instruction if register values VX and VY are equal' do
        expect{ subject }.to change{ emulator.program_counter }.by(2)
      end

      context 'when register values VX and VY are not equal' do
        before do
          emulator.general_registers[0x1] = 0xAB
          emulator.general_registers[0xA] = 0xAC
        end

        it 'does not skip next instruction' do
          expect{ subject }.not_to change{ emulator.program_counter }
        end
      end
    end

    describe '0x9XY0' do
      let(:opcode) { 0x91A0 }

      before do
        emulator.general_registers[0x1] = 0xAC
        emulator.general_registers[0xA] = 0xAB
      end

      it 'skips next instruction if register values VX and VY are not equal' do
        expect{ subject }.to change{ emulator.program_counter }.by(2)
      end

      context 'when register values VX and VY are equal' do
        before do
          emulator.general_registers[0x1] = 0xAC
          emulator.general_registers[0xA] = 0xAC
        end

        it 'does not skip next instruction' do
          expect{ subject }.not_to change{ emulator.program_counter }
        end
      end
    end

    describe '0x6XNN' do
      shared_examples 'sets general register' do |address|
        let(:opcode) { 0x60CB | address << 8 }

        it "sets #{address}nth general register" do
          subject

          expect(emulator.general_registers[address]).to eq(0x00CB)
        end
      end

      GENERAL_REGISTER_INDEX.each do |address|
        it_behaves_like 'sets general register', address
      end
    end

    describe '0x7XNN' do
      shared_examples 'adds to the general register' do |address|
        let(:opcode) { 0x7012 | address << 8 }

        before { emulator.general_registers[address] = 0x0023 }

        it "adds to the #{address}nth general register" do
          subject

          expect(emulator.general_registers[address]).to eq(0x0035)
        end
      end

      GENERAL_REGISTER_INDEX.each do |address|
        it_behaves_like 'adds to the general register', address
      end

      context 'when sum is greater than 255' do
        let(:opcode) { 0x7112 }

        before { emulator.general_registers[1] = 0xFF }

        it "sets VX result is overflown result" do
          expect { subject }.to change { emulator.general_registers[1] }.to(0x11)
        end
      end
    end

    describe '0x8XY0' do
      let(:opcode) { 0x8120 }

      before { emulator.general_registers[2] = 0x00AB }

      it "sets VX = VY" do
        expect { subject }.to change { emulator.general_registers[1] }.to(0x00AB)
      end
    end

    describe '0x8XY1' do
      let(:opcode) { 0x8121 }

      before do
        emulator.general_registers[1] = 0x0011
        emulator.general_registers[2] = 0x00AB
      end

      it "sets VX |= VY" do
        expect(0x0011 | 0x00AB).not_to eq(0)
        expect { subject }.to change { emulator.general_registers[1] }.to(0x0011 | 0x00AB)
      end

      context 'when vf_reset quirk is on' do
        let(:quirks) { { vf_reset: true } }

        before { emulator.general_registers[0xF] = 1 }

        it 'resets VF' do
          expect { subject }.to change { emulator.general_registers[0xF] }.from(1).to(0)
        end
      end
    end

    describe '0x8XY2' do
      let(:opcode) { 0x8122 }

      before do
        emulator.general_registers[1] = 0x0011
        emulator.general_registers[2] = 0x00AB
      end

      it "sets VX &= VY" do
        expect(0x0011 & 0x00AB).not_to eq(0)
        expect { subject }.to change { emulator.general_registers[1] }.to(0x0011 & 0x00AB)
      end

      context 'when vf_reset quirk is on' do
        let(:quirks) { { vf_reset: true } }

        before { emulator.general_registers[0xF] = 1 }

        it 'resets VF' do
          expect { subject }.to change { emulator.general_registers[0xF] }.from(1).to(0)
        end
      end
    end

    describe '0x8XY3' do
      let(:opcode) { 0x8123 }

      before do
        emulator.general_registers[1] = 0x0011
        emulator.general_registers[2] = 0x00AB
      end

      it "sets VX ^= VY" do
        expect(0x0011 ^ 0x00AB).not_to eq(0)
        expect { subject }.to change { emulator.general_registers[1] }.to(0x0011 ^ 0x00AB)
      end

      context 'when vf_reset quirk is on' do
        let(:quirks) { { vf_reset: true } }

        before { emulator.general_registers[0xF] = 1 }

        it 'resets VF' do
          expect { subject }.to change { emulator.general_registers[0xF] }.from(1).to(0)
        end
      end
    end

    describe '0x8XY4' do
      let(:opcode) { 0x8124 }

      before do
        emulator.general_registers[1] = 0x0011
        emulator.general_registers[2] = 0x00AB
      end

      it "sets VX += VY" do
        expect { subject }.to change { emulator.general_registers[1] }.to(0x0011 + 0x00AB)
      end

      context 'when sum is greater than 255' do
        before do
          emulator.general_registers[1] = 0xFF
          emulator.general_registers[2] = 0x02
        end

        it "sets VX result is overflown result" do
          expect { subject }.to change { emulator.general_registers[1] }.to(1)
        end

        it 'sets VF to 1' do
          expect { subject }.to change { emulator.general_registers[0xF] }.from(0).to(1)
        end
      end
    end

    describe '0x8XY5' do
      let(:opcode) { 0x8125 }

      before do
        emulator.general_registers[1] = 0x00AB
        emulator.general_registers[2] = 0x0011
      end

      it "sets VX = VX - VY" do
        expect { subject }.to change { emulator.general_registers[1] }.to(0x00AB - 0x0011)
      end

      it 'sets VF to 1' do
        expect { subject }.to change { emulator.general_registers[0xF] }.from(0).to(1)
      end

      context 'when subtraction overflows' do
        before do
          emulator.general_registers[1] = 0x0011
          emulator.general_registers[2] = 0x00AB
          emulator.general_registers[0xF] = 1
        end

        it "sets VX result is overflown result" do
          expect { subject }.to change { emulator.general_registers[1] }.to(0x0066)
        end

        it 'sets VF to 0' do
          expect { subject }.to change { emulator.general_registers[0xF] }.from(1).to(0)
        end
      end

      context 'when both subtraction sides equal' do
        before do
          emulator.general_registers[1] = 0x00AB
          emulator.general_registers[2] = 0x00AB
          emulator.general_registers[0xF] = 0
        end

        it "sets VX to 0" do
          expect { subject }.to change { emulator.general_registers[1] }.to(0)
        end

        it 'sets VF to 1' do
          expect { subject }.to change { emulator.general_registers[0xF] }.from(0).to(1)
        end
      end
    end

    describe '0x8XY7' do
      let(:opcode) { 0x8127 }

      before do
        emulator.general_registers[1] = 0x0011
        emulator.general_registers[2] = 0x00AB
      end

      it "sets VX = VY - VX" do
        expect { subject }.to change { emulator.general_registers[1] }.to(0x00AB - 0x0011)
      end

      it 'sets VF to 1' do
        expect { subject }.to change { emulator.general_registers[0xF] }.from(0).to(1)
      end

      context 'when subtraction overflows' do
        before do
          emulator.general_registers[1] = 0x00AB
          emulator.general_registers[2] = 0x0011
          emulator.general_registers[0xF] = 1
        end

        it "sets VX result is overflown result" do
          expect { subject }.to change { emulator.general_registers[1] }.to(0x0066)
        end

        it 'sets VF to 0' do
          expect { subject }.to change { emulator.general_registers[0xF] }.from(1).to(0)
        end
      end

      context 'when both subtraction sides equal' do
        before do
          emulator.general_registers[1] = 0x00AB
          emulator.general_registers[2] = 0x00AB
          emulator.general_registers[0xF] = 0
        end

        it "sets VX to 0" do
          expect { subject }.to change { emulator.general_registers[1] }.to(0)
        end

        it 'sets VF to 1' do
          expect { subject }.to change { emulator.general_registers[0xF] }.from(0).to(1)
        end
      end
    end

    describe '0x8XY6' do
      let(:opcode) { 0x8126 }

      before do
        emulator.general_registers[1] = 0x0011
        emulator.general_registers[2] = 0x0045
      end

      it "copies VY to VX and shifts to the right" do
        expect { subject }.to change { emulator.general_registers[1] }.from(0x0011).to(0x0022)
      end

      it 'sets VF to 1' do
        expect { subject }.to change { emulator.general_registers[0xF] }.from(0).to(1)
      end

      context 'when shifted out bit is 0' do
        before do
          emulator.general_registers[2] = 0x0044
          emulator.general_registers[0xF] = 1
        end

        it "copies VY to VX and shifts to the right" do
          expect { subject }.to change { emulator.general_registers[1] }.from(0x0011).to(0x0022)
        end

        it 'sets VF to 0' do
          expect { subject }.to change { emulator.general_registers[0xF] }.from(1).to(0)
        end
      end

      context 'with shifting quirk' do
        let(:quirks) { { shifting: true } }

        it "shifts VX to the right" do
          expect { subject }.to change { emulator.general_registers[1] }.from(0x0011).to(0x0008)
        end

        it 'sets VF to 1' do
          expect { subject }.to change { emulator.general_registers[0xF] }.from(0).to(1)
        end

        context 'when shifted out bit is 0' do
          before do
            emulator.general_registers[1] = 0x0010
            emulator.general_registers[0xF] = 1
          end

          it "shifts VX to the right" do
            expect { subject }.to change { emulator.general_registers[1] }.from(0x0010).to(0x0008)
          end

          it 'sets VF to 0' do
            expect { subject }.to change { emulator.general_registers[0xF] }.from(1).to(0)
          end
        end
      end
    end

    describe '0x8XYE' do
      let(:opcode) { 0x812E }

      before do
        emulator.general_registers[1] = 0x00EE
        emulator.general_registers[2] = 0x00FF
      end

      it "copies VY to VX and shifts to the left" do
        expect { subject }.to change { emulator.general_registers[1] }.from(0x00EE).to(0x00FE)
      end

      it 'sets VF to 1' do
        expect { subject }.to change { emulator.general_registers[0xF] }.from(0).to(1)
      end

      context 'when shifted out bit is 0' do
        before do
          emulator.general_registers[1] = 0x00AA
          emulator.general_registers[2] = 0x0010
          emulator.general_registers[0xF] = 1
        end

        it "copies VY to VX and shifts to the left" do
          expect { subject }.to change { emulator.general_registers[1] }.from(0x00AA).to(0x0020)
        end

        it 'sets VF to 0' do
          expect { subject }.to change { emulator.general_registers[0xF] }.from(1).to(0)
        end
      end

      context 'with shifting quirk' do
        let(:quirks) { { shifting: true } }

        it "shifts VX to the left" do
          expect { subject }.to change { emulator.general_registers[1] }.from(0x00EE).to(0x00DC)
        end

        it 'sets VF to 1' do
          expect { subject }.to change { emulator.general_registers[0xF] }.from(0).to(1)
        end

        context 'when shifted out bit is 0' do
          before do
            emulator.general_registers[1] = 0x0010
            emulator.general_registers[0xF] = 1
          end

          it "shifts VX to the left" do
            expect { subject }.to change { emulator.general_registers[1] }.from(0x0010).to(0x0020)
          end

          it 'sets VF to 0' do
            expect { subject }.to change { emulator.general_registers[0xF] }.from(1).to(0)
          end
        end
      end
    end

    describe '0xANNN' do
      let(:opcode) { 0xA678 }

      it "sets index register" do
        subject

        expect(emulator.index_register).to eq(0x0678)
      end
    end

    describe '0xBNNN' do
      let(:opcode) { 0xB123 }

      before { emulator.general_registers[0] = 0x0002 }

      it 'sets program counter to NNN + V0' do
        subject

        expect(emulator.program_counter).to eq(0x0125)
      end

      context 'when jumping quirk is on' do
        let(:quirks) { { jumping: true } }

        before { emulator.general_registers[1] = 0x0003 }

        it 'sets program counter to NNN + VX' do
          subject

          expect(emulator.program_counter).to eq(0x0126)
        end
      end
    end

    describe '0xCXNN' do
      # not the best code, but I'm too lazy to stub Kernel.rand
      let(:opcode) { 0xC123 }

      it 'sets VX to random number' do
        subject

        expect(emulator.general_registers[1]).to be_between(0, 0xFF)
        expect(emulator.general_registers[1]).to eq(emulator.general_registers[1] & (opcode & 0x00FF))
      end
    end

    describe '0xDXYN' do
      let(:opcode) { 0xD000 | x_register << 8 | y_register << 4 | height }

      let(:x_register) { 0x4 }
      let(:y_register) { 0x3 }
      let(:height) { 0x1 }

      let(:x_value) { 0x0A }
      let(:y_value) { 0x0B }

      before do
        emulator.general_registers[x_register] = x_value
        emulator.general_registers[y_register] = y_value

        emulator.memory[0x0] = 0b11111111
        emulator.memory[0x1] = 0b11111111

        emulator.general_registers[0xF] = 1
      end

      it "sets display buffer" do
        subject

        buffer = emulator.display_buffer.buffer
        last_index = buffer.size - 1
        start_index = x_value + y_value * 64
        expect(buffer[(start_index - 1)..last_index]).to start_with([0, 1, 1, 1, 1, 1, 1, 1, 1, 0])
        expect(buffer[0..(start_index - 1)]).to all(be_zero)
        expect(buffer[start_index + 8..last_index]).to all(be_zero)
      end

      it 'sets VF to 0' do
        expect{ subject }.to change{ emulator.general_registers[0xF] }.from(1).to(0)
      end

      context 'when turning off pixel' do
        let(:x_value) { 30 }
        let(:y_value) { 28 }

        before do
          emulator.display_buffer.set_pixel(x_value, y_value, 1)
          emulator.general_registers[0xF] = 0
        end

        it 'sets VF to 1' do
          expect{ subject }.to change{ emulator.general_registers[0xF] }.from(0).to(1)
        end
      end
    end

    describe '0xEX9E' do
      let(:opcode) { 0xE19E }

      before do
        emulator.general_registers[1] = 0x0A
        emulator.key_pressed!(0x0A)
      end

      it 'skips next instruction if key is pressed' do
        expect{ subject }.to change{ emulator.program_counter }.by(2)
      end

      context 'when key is not pressed' do
        before do
          emulator.key_released!(0x0A)
          emulator.key_pressed!(0x0B)
        end

        it 'does not skip next instruction' do
          expect{ subject }.not_to change{ emulator.program_counter }
        end
      end
    end

    describe '0xEXA1' do
      let(:opcode) { 0xE1A1 }

      before do
        emulator.general_registers[1] = 0x0A
        emulator.key_pressed!(0x0B)
      end

      it 'skips next instruction if key is not pressed' do
        expect{ subject }.to change{ emulator.program_counter }.by(2)
      end

      context 'when key is pressed' do
        before do
          emulator.key_released!(0x0B)
          emulator.key_pressed!(0x0A)
        end

        it 'does not skip next instruction' do
          expect{ subject }.not_to change{ emulator.program_counter }
        end
      end
    end

    describe '0xFX07' do
      let(:opcode) { 0xFE07 }

      before { emulator.delay_timer = 0x0A }

      it 'sets VX to delay timer' do
        subject

        expect(emulator.general_registers[0x0E]).to eq(0x0A)
      end
    end

    describe '0xFX0A' do
      let(:opcode) { 0xFE0A }

      it 'waits for keypress' do
        expect{ subject }.to change{ emulator.program_counter }.by(-2)
      end

      context 'when key is pressed' do
        before { emulator.key_pressed!(0x0A) }

        it 'sets VX to pressed key' do
          expect{ subject }.to change{ emulator.general_registers[0x0E] }.to(0x0A)
        end
      end
    end

    describe '0xFX15' do
      let(:opcode) { 0xFE15 }

      before { emulator.general_registers[0x0E] = 0x0A }

      it 'sets delay timer to VX' do
        expect{ subject }.to change { emulator.delay_timer }.to(0x0A)
      end
    end

    describe '0xFX18' do
      let(:opcode) { 0xFE18 }

      before { emulator.general_registers[0x0E] = 0x0A }

      it 'sets delay timer to VX' do
        expect{ subject }.to change { emulator.sound_timer }.to(0x0A)
      end
    end

    describe '0xFX1E' do
      let(:opcode) { 0xFE1E }

      before do
        emulator.index_register = 0x0A
        emulator.general_registers[0x0E] = 0x0B
      end

      it 'adds VX to index register' do
        expect{ subject }.to change { emulator.index_register }.to(0x0A + 0x0B)
      end

      context 'when sum is greater than 0xFFFF' do
        before do
          emulator.index_register = 0xFFFE
          emulator.general_registers[0x0E] = 0x0002
        end

        it 'adds VX to index register' do
          expect{ subject }.to change { emulator.index_register }.to(0x0000)
        end
      end
    end

    describe '0xFX29' do
      let(:opcode) { 0xFA29 }

      before { emulator.general_registers[0xA] = 0x0B }

      it 'sets index register to font address' do
        subject

        expect(emulator.index_register).to eq(0x50 + 0x0B * 5)
      end
    end

    describe '0xFX33' do
      let(:opcode) { 0xFA33 }

      before do
        emulator.index_register = 0x0A
        emulator.general_registers[0xA] = 123
      end

      it 'sets BCD representation of VX at index register' do
        subject

        expect(emulator.memory[0x0A]).to eq(1)
        expect(emulator.memory[0x0B]).to eq(2)
        expect(emulator.memory[0x0C]).to eq(3)
      end
    end

    describe '0xFX55' do
      let(:opcode) { 0xFA55 }
      let(:offset) { 0xA }

      before do
        emulator.index_register = 0x03
        (0..offset).each do |i|
          emulator.general_registers[i] = i
        end
      end

      it 'sets memory from index register to VX' do
        subject

        expect(emulator.memory[0x03..0x0D]).to eq((0..offset).to_a)
      end

      context 'when memory quirk is on' do
        let(:quirks) { { memory: true } }

        before { emulator.index_register = 0x02 }

        it 'adds offset to index register' do
          expect { subject }.to change { emulator.index_register }.to(0x02 + offset + 1)
        end
      end
    end

    describe '0xFX65' do
      let(:opcode) { 0xFA65 }
      let(:offset) { 0xA }

      before do
        emulator.index_register = 0x03
        (0..offset).each do |i|
          emulator.memory[0x03 + i] = i
        end
      end

      it 'sets VX to memory from index register' do
        subject

        expect(emulator.general_registers[0..offset]).to eq((0..offset).to_a)
      end

      context 'when memory quirk is on' do
        let(:quirks) { { memory: true } }

        before { emulator.index_register = 0x02 }

        it 'adds offset to index register' do
          expect { subject }.to change { emulator.index_register }.to(0x02 + offset + 1)
        end
      end
    end
  end
end
