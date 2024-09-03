# frozen_string_literal: true

require 'emulator'

RSpec.describe Emulator::Emulator do
  let(:emulator) { described_class.new }

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

    describe '0x1XXX' do
      let(:opcode) { 0x1ABC }

      it 'set the program counter' do
        subject

        expect(emulator.program_counter).to eq(0x0ABC)
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
    end

    describe '0xANNN' do
      let(:opcode) { 0xA678 }

      it "sets index register" do
        subject

        expect(emulator.index_register).to eq(0x0678)
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
    end
  end
end
