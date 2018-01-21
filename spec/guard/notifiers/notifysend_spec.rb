require 'spec_helper'

describe Guard::Notifier::NotifySend do

  let(:fake_notifysend) do
    Class.new do
      def self.show(options) end
    end
  end

  before do
    stub_const 'NotifySend', :fake_notifysend
  end

  describe '.available?' do
    context 'without the silent option' do
      it 'shows an error message when not available on the host OS' do
        expect(::Guard::UI).to receive(:error).with 'The :notifysend notifier runs only on Linux, FreeBSD, OpenBSD and Solaris with the libnotify-bin package installed.'
        expect(RbConfig::CONFIG).to receive(:[]).with('host_os').and_return 'darwin'
        subject.available?
      end
    end

    context 'with the silent option' do
      it 'does not show an error message when not available on the host OS' do
        expect(::Guard::UI).not_to receive(:error).with 'The :notifysend notifier runs only on Linux, FreeBSD, OpenBSD and Solaris with the libnotify-bin package installed.'
        expect(RbConfig::CONFIG).to receive(:[]).with('host_os').and_return 'darwin'
        subject.available?(true)
      end
    end
  end

  describe '.notify' do
    context 'without additional options' do
      it 'shows the notification with the default options' do
        expect(subject).to receive(:system) do |command, *arguments|
          expect(command).to eql 'notify-send'
          expect(arguments).to include '-i', '/tmp/welcome.png'
          expect(arguments).to include '-u', 'low'
          expect(arguments).to include '-t', '3000'
          expect(arguments).to include '-h', 'int:transient:1'
        end
        subject.notify('success', 'Welcome', 'Welcome to Guard', '/tmp/welcome.png', { })
      end
    end

    context 'with additional options' do
      it 'can override the default options' do
        expect(subject).to receive(:system) do |command, *arguments|
          expect(command).to eql 'notify-send'
          expect(arguments).to include '-i', '/tmp/wait.png'
          expect(arguments).to include '-u', 'critical'
          expect(arguments).to include '-t', '5'
        end
        subject.notify('pending', 'Waiting', 'Waiting for something', '/tmp/wait.png', {
            :t => 5,
            :u => :critical
        })
      end
    end

  end
end
