require 'spec_helper'


describe Guard::Notifier::FileNotifier do

  describe '.available?' do
    it 'is true if there is a file in options' do
      expect(subject).to be_available(true, :path => '.guard_result')
    end

    it 'is false if there is no path in options' do
      expect(subject).not_to be_available
    end
  end

  describe '.notify' do
    it 'writes to a file on success' do
      expect(subject).to receive(:write).with('tmp/guard_result', "success\nany title\nany message\n")

      subject.notify('success', 'any title', 'any message', 'any image', { :path => 'tmp/guard_result' })
    end

    it 'also writes to a file on failure' do
      expect(subject).to receive(:write).with('tmp/guard_result', "failed\nany title\nany message\n")

      subject.notify('failed', 'any title', 'any message', 'any image', { :path => 'tmp/guard_result' })
    end

    # We don't have a way to return false in .available? when no path is
    # specified. So, we just don't do anything in .notify if there's no path.
    it 'does not write to a file if no path is specified' do
      expect(subject).not_to receive(:write)
      expect(::Guard::UI).to receive(:error).with ":file notifier requires a :path option"

      subject.notify('success', 'any title', 'any message', 'any image', { })
    end
  end
end
