# frozen_string_literal: true

require 'emulator'

RSpec.describe Emulator::Emulator do

  describe '#initialize' do
    subject { described_class.new }

    it 'has fonts in memory' do
      expect(subject.memory[0x50..(0x50 + Emulator::Emulator::FONTS.size - 1)]).to eq(Emulator::Emulator::FONTS)
    end
  end

  describe '#load_data' do
    subject { emulator.load_data(data) }

    let(:emulator) { described_class.new }
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

    let(:emulator) { described_class.new }
    let(:data) { [1, 2] }

    it 'returns the opcode' do
      expect(subject).to eq(0x0102)
    end
  end
end
