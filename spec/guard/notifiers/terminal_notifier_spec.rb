require 'spec_helper'

describe Guard::Notifier::TerminalNotifier do

  let(:fake_terminal_notifier) do
    Module.new do
      def self.execute(options) end
    end
  end

  before do
    allow(subject).to receive(:require)
    stub_const 'TerminalNotifier::Guard', fake_terminal_notifier
  end

  describe '.available?' do
    context 'without the silent option' do
      it 'shows an error message when not available on the host OS' do
        expect(::Guard::UI).to receive(:error).with 'The :terminal_notifier only runs on Mac OS X 10.8 and later.'
        allow(::TerminalNotifier::Guard).to receive(:available?).and_return(false)
        subject.available?
      end
    end
  end

  describe '.notify' do
    it 'should call the notifier.' do
      expect(::TerminalNotifier::Guard).to receive(:execute).with(
        false,
        { :title => 'any title', :type => :success, :message => 'any message' }
      )
      subject.notify('success', 'any title', 'any message', 'any image', { })
    end

    it "should allow the title to be customized" do
      expect(::TerminalNotifier::Guard).to receive(:execute).with(
        false,
        { :title => 'any title', :message => 'any message', :type => :error }
      )

      subject.notify('error', 'any title', 'any message', 'any image', { })
    end

    context 'without a title set' do
      it 'should show the app name in the title' do
        expect(::TerminalNotifier::Guard).to receive(:execute).with(
          false,
          { :title => 'FooBar Success', :type => :success, :message => 'any message' }
        )

        subject.notify('success', nil, 'any message', 'any image', { :app_name => 'FooBar' })
      end
    end
  end
end
