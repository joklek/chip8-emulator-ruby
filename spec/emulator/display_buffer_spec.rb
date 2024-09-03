# frozen_string_literal: true

require 'emulator'

RSpec.describe Emulator::DisplayBuffer do
  let(:display_buffer) { described_class.new }

  describe '#initialize' do
    subject { display_buffer }

    it 'creates a buffer of 64 * 32 pixels' do
      expect(subject.buffer.size).to eq(64 * 32)
    end
  end

  describe '#reset' do
    subject { display_buffer.reset }

    before do
      display_buffer.buffer[0] = 1
      display_buffer.buffer[display_buffer.buffer.size - 1] = 123
    end

    it 'resets the buffer' do
      expect(display_buffer.buffer).to start_with([1])
      expect(display_buffer.buffer).to end_with([123])

      subject

      expect(display_buffer.buffer).to all(eq(0))
    end

    it 'marks the buffer as dirty' do
      expect(display_buffer).not_to be_dirty

      subject

      expect(display_buffer).to be_dirty
    end
  end

  describe '#set_pixel' do
    subject { display_buffer.set_pixel(x, y, value) }

    let(:x) { 12 }
    let(:y) { 4 }
    let(:value) { 1 }

    it 'sets a pixel' do
      expect(subject).to be(true)
      expect(display_buffer.buffer[y * 64 + x]).to eq(1)
    end

    it 'marks the buffer as dirty' do
      expect { subject }.to change { display_buffer.dirty? }.from(false).to(true)
    end

    context 'when the pixel is already set' do
      before do
        display_buffer.buffer[y * 64 + x] = 1
      end

      it 'does not set the pixel' do
        expect { subject }.not_to change { display_buffer.buffer[y * 64 + x] }
      end

      it 'returns false' do
        expect(subject).to be(false)
      end

      it 'does not mark the buffer as dirty' do
        expect { subject }.not_to change { display_buffer.dirty? }
      end
    end

    [64, -1].each do |invalid_x|
      context "when x is #{invalid_x}" do
        let(:x) { invalid_x }

        it 'does not set a pixel' do
          expect { subject }.not_to change { display_buffer.buffer }
        end

        it 'returns false' do
          expect(subject).to be(false)
        end

        it 'does not mark the buffer as dirty' do
          expect { subject }.not_to change { display_buffer.dirty? }
        end
      end
    end

    [32, -1].each do |invalid_y|
      context "when y is #{invalid_y}" do
        let(:y) { invalid_y }

        it 'does not set a pixel' do
          expect { subject }.not_to change { display_buffer.buffer }
        end

        it 'returns false' do
          expect(subject).to be(false)
        end

        it 'does not mark the buffer as dirty' do
          expect { subject }.not_to change { display_buffer.dirty? }
        end
      end
    end
  end
end
