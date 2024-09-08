# frozen_string_literal: true

require 'emulator'

RSpec.describe Emulator::DisplayBuffer do
  let(:display_buffer) { described_class.new(quirks_config) }
  let(:quirks_config) { {} }

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

      expect(display_buffer.buffer).to all(be_zero)
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

    shared_examples 'marks the buffer as dirty' do
      it 'marks the buffer as dirty' do
        expect { subject }.to change { display_buffer.dirty? }.from(false).to(true)
      end
    end

    shared_examples 'does not mark the buffer as dirty' do
      it 'does not mark the buffer as dirty' do
        expect { subject }.not_to change { display_buffer.dirty? }
      end
    end

    shared_examples 'does not set a pixel' do
      it 'does not change pixel' do
        expect { subject }.not_to change { display_buffer.buffer[y * 64 + x] }
      end

      it 'returns false' do
        expect(subject).to be_falsey
      end

      it_behaves_like 'does not mark the buffer as dirty'
    end

    it 'flips pixel' do
      expect { subject }.to change { display_buffer.buffer[y * 64 + x] }.from(0).to(1)
    end

    it 'returns false' do
      expect(subject).to be_falsey
    end

    it_behaves_like 'marks the buffer as dirty'

    context 'when set pixel as 0 when it is 1' do
      let(:value) { 0 }

      before do
        display_buffer.buffer[y * 64 + x] = 1
      end

      it_behaves_like 'does not set a pixel'
    end

    context 'when the pixel is already set' do
      before do
        display_buffer.buffer[y * 64 + x] = 1
      end

      it 'flips pixel' do
        expect { subject }.to change { display_buffer.buffer[y * 64 + x] }.from(1).to(0)
      end

      it 'indicates turning pixel turn off' do
        expect(subject).to be(true)
      end

      it_behaves_like 'marks the buffer as dirty'
    end

    context "when x is out of bounds" do
      let(:x) { 64 }
      let(:wrapped_x) { x % 64 }

      context 'when clipping is enabled' do
        let(:quirks_config) { { clipping: true } }

        it_behaves_like 'does not set a pixel'
      end

      it 'sets wrapped pixel' do
        expect { subject }.to change { display_buffer.buffer[y * 64 + wrapped_x] }.from(0).to(1)
      end

      it 'returns false' do
        expect(subject).to be_falsey
      end

      it_behaves_like 'marks the buffer as dirty'
    end

    context "when y is out of bounds" do
      let(:y) { 32 }
      let(:wrapped_y) { y % 32 }

      context 'when clipping is enabled' do
        let(:quirks_config) { { clipping: true } }

        it_behaves_like 'does not set a pixel'
      end

      it 'sets wrapped pixel' do
        expect { subject }.to change { display_buffer.buffer[wrapped_y * 64 + x] }.from(0).to(1)
      end

      it 'returns false' do
        expect(subject).to be_falsey
      end

      it_behaves_like 'marks the buffer as dirty'
    end
  end
end
