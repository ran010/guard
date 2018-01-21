require 'spec_helper'

describe Guard::Notifier::Tmux do

  describe '.available?' do
    context 'when the TMUX environment variable is set' do
      before :each do
        ENV['TMUX'] = 'something'
      end

      it 'should return true' do
        expect(subject.available?).to be_truthy
      end
    end

    context 'when the TMUX environment variable is not set' do
      before :each do
        ENV['TMUX'] = nil
      end

      context 'without the silent option' do
        it 'shows an error message when the TMUX environment variable is not set' do
          expect(::Guard::UI).to receive(:error).with 'The :tmux notifier runs only on when Guard is executed inside of a tmux session.'
          subject.available?
        end
      end

      context 'with the silent option' do
        it 'should return false' do
          expect(subject.available?(true)).to be_falsey
        end
      end
    end
  end

  describe '.notify' do
    it 'should set the tmux status bar color to green on success' do
      expect(subject).to receive(:system).with 'tmux set status-left-bg green'

      subject.notify('success', 'any title', 'any message', 'any image', { })
    end

    it 'should set the tmux status bar color to black on success when black is passed in as an option' do
      expect(subject).to receive(:system).with "tmux set status-left-bg black"

      subject.notify('success', 'any title', 'any message', 'any image', { :success => 'black' })
    end

    it 'should set the tmux status bar color to red on failure' do
      expect(subject).to receive(:system).with 'tmux set status-left-bg red'

      subject.notify('failed', 'any title', 'any message', 'any image', { })
    end

    it 'should set the tmux status bar color to yellow on pending' do
      expect(subject).to receive(:system).with 'tmux set status-left-bg yellow'

      subject.notify('pending', 'any title', 'any message', 'any image', { })
    end

    it 'should set the tmux status bar color to green on notify' do
      expect(subject).to receive(:system).with 'tmux set status-left-bg green'

      subject.notify('notify', 'any title', 'any message', 'any image', { })
    end

    it 'should set the right tmux status bar color on success when the right status bar is passed in as an option' do
      expect(subject).to receive(:system).with 'tmux set status-right-bg green'

      subject.notify('success', 'any title', 'any message', 'any image', { :color_location => 'status-right-bg' })
    end

    it 'calls display_message if the display_message flag is set' do
      allow(subject).to receive(:system).and_return(true)
      expect(subject).to receive(:display_message).with('notify', 'any title', 'any message', { :display_message => true })

      subject.notify('notify', 'any title', 'any message', 'any image', { :display_message => true })
    end

    it 'does not call display message if the display_message flag is not set' do
      allow(subject).to receive(:system).and_return(true)
      expect(subject).to receive(:display_message).never

      subject.notify('notify', 'any title', 'any message', 'any image', { })
    end
  end

  describe '.display_message' do
    before do
      allow(subject).to receive(:system).and_return(true)
    end

    it 'sets the display-time' do
      expect(subject).to receive(:system).with('tmux set display-time 3000')
      subject.display_message 'success', 'any title', 'any message', :timeout => 3
    end

    it 'displays the message' do
      expect(subject).to receive(:system).with('tmux display-message \'any title - any message\'').once
      subject.display_message 'success', 'any title', 'any message'
    end

    it 'handles line-breaks' do
      expect(subject).to receive(:system).with('tmux display-message \'any title - any message xx line two\'').once
      subject.display_message 'success', 'any title', "any message\nline two", :line_separator => ' xx '
    end

    context 'with success message type options' do
      it 'formats the message' do
        expect(subject).to receive(:system).with('tmux display-message \'[any title] => any message - line two\'').once
        subject.display_message 'success', 'any title', "any message\nline two", :success_message_format => '[%s] => %s', :default_message_format => '(%s) -> %s'
      end

      it 'sets the foreground color based on the type for success' do
        expect(subject).to receive(:system).with('tmux set message-fg green')
        subject.display_message 'success', 'any title', 'any message', { :success_message_color => 'green' }
      end

      it 'sets the background color' do
        expect(subject).to receive(:system).with('tmux set message-bg blue')
        subject.display_message 'success', 'any title', 'any message', { :success => :blue }
      end
    end

    context 'with pending message type options' do
      it 'formats the message' do
        expect(subject).to receive(:system).with('tmux display-message \'[any title] === any message - line two\'').once
        subject.display_message 'pending', 'any title', "any message\nline two", :pending_message_format => '[%s] === %s', :default_message_format => '(%s) -> %s'
      end

      it 'sets the foreground color' do
        expect(subject).to receive(:system).with('tmux set message-fg blue')
        subject.display_message 'pending', 'any title', 'any message', { :pending_message_color => 'blue' }
      end

      it 'sets the background color' do
        expect(subject).to receive(:system).with('tmux set message-bg white')
        subject.display_message 'pending', 'any title', 'any message', { :pending => :white }
      end
    end

    context 'with failed message type options' do
      it 'formats the message' do
        expect(subject).to receive(:system).with('tmux display-message \'[any title] <=> any message - line two\'').once
        subject.display_message 'failed', 'any title', "any message\nline two", :failed_message_format => '[%s] <=> %s', :default_message_format => '(%s) -> %s'
      end

      it 'sets the foreground color' do
        expect(subject).to receive(:system).with('tmux set message-fg red')
        subject.display_message 'failed', 'any title', 'any message', { :failed_message_color => 'red' }
      end

      it 'sets the background color' do
        expect(subject).to receive(:system).with('tmux set message-bg black')
        subject.display_message 'failed', 'any title', 'any message', { :failed => :black }
      end
    end

  end

  describe '.turn_on' do
    before do
      allow(subject).to receive(:`).and_return("option1 setting1\noption2 setting2\n")
      allow(subject).to receive(:system).and_return(true)
    end

    it 'quiets the tmux output' do
      expect(subject).to receive(:system).with 'tmux set quiet on'
      subject.turn_on
    end

    context 'when off' do
      before do
        subject.turn_off
      end

      it 'resets the options store' do
        expect(subject).to receive(:reset_options_store)
        subject.turn_on
      end

      it 'saves the current tmux options' do
        expect(subject).to receive(:`).with('tmux show')
        subject.turn_on
      end
    end

    context 'when on' do
      before do
        subject.turn_on
      end

      it 'does not reset the options store' do
        expect(subject).not_to receive(:reset_options_store)
        subject.turn_on
      end

      it 'does not save the current tmux options' do
        expect(subject).not_to receive(:`).with('tmux show')
        subject.turn_on
      end
    end
  end

  describe '.turn_off' do
    before do
      allow(subject).to receive(:`).and_return("option1 setting1\noption2 setting2\n")
      allow(subject).to receive(:system).and_return(true)
    end

    context 'when on' do
      before do
        subject.turn_on
      end

      it 'restores the tmux options' do
        expect(subject).to receive(:system).with('tmux set option2 setting2')
        expect(subject).to receive(:system).with('tmux set -u status-left-bg')
        expect(subject).to receive(:system).with('tmux set option1 setting1')
        expect(subject).to receive(:system).with('tmux set -u status-right-bg')
        expect(subject).to receive(:system).with('tmux set -u status-right-fg')
        expect(subject).to receive(:system).with('tmux set -u status-left-fg')
        expect(subject).to receive(:system).with('tmux set -u message-fg')
        expect(subject).to receive(:system).with('tmux set -u message-bg')
        subject.turn_off
      end

      it 'resets the options store' do
        expect(subject).to receive(:reset_options_store)
        subject.turn_off
      end

      it 'unquiets the tmux output' do
        expect(subject).to receive(:system).with 'tmux set quiet off'
        subject.turn_off
      end
    end

    context 'when off' do
      before do
        subject.turn_off
      end

      it 'does not restore the tmux options' do
        expect(subject).not_to receive(:system).with('tmux set -u status-left-bg')
        expect(subject).not_to receive(:system).with('tmux set -u status-right-bg')
        expect(subject).not_to receive(:system).with('tmux set -u status-right-fg')
        expect(subject).not_to receive(:system).with('tmux set -u status-left-fg')
        expect(subject).not_to receive(:system).with('tmux set -u message-fg')
        expect(subject).not_to receive(:system).with('tmux set -u message-bg')
        subject.turn_off
      end

      it 'does not reset the options store' do
        expect(subject).not_to receive(:reset_options_store)
        subject.turn_off
      end

      it 'unquiets the tmux output' do
        expect(subject).to receive(:system).with 'tmux set quiet off'
        subject.turn_off
      end
    end
  end
end
