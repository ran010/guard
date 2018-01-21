require 'spec_helper'

describe Guard::Notifier do

  describe '.turn_on' do
    context 'with configured notifications' do
      before do
        Guard::Notifier.notifications = [{ :name => :gntp, :options => { } }]
      end

      it 'shows the used notifications' do
        expect(Guard::UI).to receive(:info).with 'Guard uses GNTP to send notifications.'
        Guard::Notifier.turn_on
      end

      it 'enables the notifications' do
        Guard::Notifier.turn_on
        expect(Guard::Notifier).to be_enabled
      end

      it 'turns on the defined notification module' do
        expect(::Guard::Notifier::GNTP).to receive(:turn_on)
        Guard::Notifier.turn_on
      end
    end

    context 'without configured notifications' do
      before do
        Guard::Notifier.notifications = []
      end

      context 'when notifications are globally enabled' do
        before do
          ::Guard.options = { }
          expect(::Guard.options).to receive(:[]).with(:notify).and_return true
        end

        it 'tries to add each available notification silently' do
          expect(Guard::Notifier).to receive(:add_notification).with(:gntp, { }, true).and_return false
          expect(Guard::Notifier).to receive(:add_notification).with(:growl, { }, true).and_return false
          expect(Guard::Notifier).to receive(:add_notification).with(:growl_notify, { }, true).and_return false
          expect(Guard::Notifier).to receive(:add_notification).with(:terminal_notifier, { }, true).and_return false
          expect(Guard::Notifier).to receive(:add_notification).with(:libnotify, { }, true).and_return false
          expect(Guard::Notifier).to receive(:add_notification).with(:notifysend, { }, true).and_return false
          expect(Guard::Notifier).to receive(:add_notification).with(:notifu, { }, true).and_return false
          expect(Guard::Notifier).to receive(:add_notification).with(:emacs, { }, true).and_return false
          expect(Guard::Notifier).to receive(:add_notification).with(:terminal_title, { }, true).and_return false
          expect(Guard::Notifier).to receive(:add_notification).with(:tmux, { }, true).and_return false
          expect(Guard::Notifier).to receive(:add_notification).with(:file, { }, true).and_return false
          Guard::Notifier.turn_on
        end

        it 'adds only the first notification per group' do
          expect(Guard::Notifier).to receive(:add_notification).with(:gntp, { }, true).and_return false
          expect(Guard::Notifier).to receive(:add_notification).with(:growl, { }, true).and_return false
          expect(Guard::Notifier).to receive(:add_notification).with(:growl_notify, { }, true).and_return true
          expect(Guard::Notifier).not_to receive(:add_notification).with(:terminal_notifier, { }, true)
          expect(Guard::Notifier).not_to receive(:add_notification).with(:libnotify, { }, true)
          expect(Guard::Notifier).not_to receive(:add_notification).with(:notifysend, { }, true)
          expect(Guard::Notifier).not_to receive(:add_notification).with(:notifu, { }, true)
          expect(Guard::Notifier).to receive(:add_notification).with(:emacs, { }, true)
          expect(Guard::Notifier).to receive(:add_notification).with(:terminal_title, { }, true)
          expect(Guard::Notifier).to receive(:add_notification).with(:tmux, { }, true)
          expect(Guard::Notifier).to receive(:add_notification).with(:file, { }, true)
          Guard::Notifier.turn_on
        end

        it 'does enable the notifications when a library is available' do
          allow(Guard::Notifier).to receive(:add_notification) {
            Guard::Notifier.notifications = [{ :name => :gntp, :options => { } }]
            true
          }
          Guard::Notifier.turn_on
          expect(Guard::Notifier).to be_enabled
        end

        it 'does turn on the notification module for libraries that are available' do
          expect(::Guard::Notifier::GNTP).to receive(:turn_on)
          allow(Guard::Notifier).to receive(:add_notification) {
            Guard::Notifier.notifications = [{ :name => :gntp, :options => { } }]
            true
          }
          Guard::Notifier.turn_on
        end

        it 'does not enable the notifications when no library is available' do
          allow(Guard::Notifier).to receive(:add_notification).and_return false
          Guard::Notifier.turn_on
          expect(Guard::Notifier).not_to be_enabled
        end
      end

      context 'when notifications are globally disabled' do
        before do
          ::Guard.options = { }
          expect(::Guard.options).to receive(:[]).with(:notify).and_return false
        end

        it 'does not try to add each available notification silently' do
          expect(Guard::Notifier).not_to receive(:auto_detect_notification)
          Guard::Notifier.turn_on
          expect(Guard::Notifier).not_to be_enabled
        end
      end
    end
  end

  describe '.turn_off' do
    before { ENV['GUARD_NOTIFY'] = 'true' }

    it 'disables the notifications' do
      Guard::Notifier.turn_off
      expect(ENV['GUARD_NOTIFY']).to eq('false')
    end

    context 'when turned on with available notifications' do
      before do
        Guard::Notifier.notifications = [{ :name => :gntp, :options => { } }]
      end

      it 'turns off each notification' do
        expect(::Guard::Notifier::GNTP).to receive(:turn_off)
        Guard::Notifier.turn_off
      end
    end
  end

  describe 'toggle_notification' do
    before { allow(::Guard::UI).to receive(:info) }

    it 'disables the notifications when enabled' do
      ENV['GUARD_NOTIFY'] = 'true'
      expect(::Guard::Notifier).to receive(:turn_off)
      subject.toggle
    end

    it 'enables the notifications when disabled' do
      ENV['GUARD_NOTIFY'] = 'false'
      expect(::Guard::Notifier).to receive(:turn_on)
      subject.toggle
    end
  end

  describe '.enabled?' do
    context 'when enabled' do
      before { ENV['GUARD_NOTIFY'] = 'true' }

      it { is_expected.to be_enabled }
    end

    context 'when disabled' do
      before { ENV['GUARD_NOTIFY'] = 'false' }

      it { is_expected.not_to be_enabled }
    end
  end

  describe '.add_notification' do
    before do
      Guard::Notifier.notifications = []
    end

    context 'for an unknown notification library' do
      it 'does not add the library' do
        Guard::Notifier.add_notification(:unknown)
        expect(Guard::Notifier.notifications).to be_empty
      end
    end

    context 'for an notification library with the name :off' do
      it 'disables the notifier' do
        ENV['GUARD_NOTIFY'] = 'true'
        expect(Guard::Notifier).to be_enabled
        Guard::Notifier.add_notification(:off)
        expect(Guard::Notifier).not_to be_enabled
      end
    end

    context 'for a supported notification library' do
      context 'that is available' do
        it 'adds the notifier to the notifications' do
          expect(Guard::Notifier::GNTP).to receive(:available?).and_return true
          Guard::Notifier.add_notification(:gntp, { :param => 1 })
          expect(Guard::Notifier.notifications).to include({ :name => :gntp, :options => { :param => 1 } })
        end
      end

      context 'that is not available' do
        it 'does not add the notifier to the notifications' do
          expect(Guard::Notifier::GNTP).to receive(:available?).and_return false
          Guard::Notifier.add_notification(:gntp, { :param => 1 })
          expect(Guard::Notifier.notifications).not_to include({ :name => :gntp, :options => { :param => 1 } })
        end
      end
    end
  end

  describe '.notify' do
    context 'when notifications are enabled' do
      before do
        Guard::Notifier.notifications = [{ :name => :gntp, :options => { } }]
        allow(Guard::Notifier).to receive(:enabled?).and_return true
      end

      it 'uses the :success image when no image is defined' do
        expect(Guard::Notifier::GNTP).to receive(:notify).with('success', 'Hi', 'Hi to everyone', /success.png/, { })
        ::Guard::Notifier.notify('Hi to everyone', :title => 'Hi')
      end

      it 'uses "Guard" as title when no title is defined' do
        expect(Guard::Notifier::GNTP).to receive(:notify).with('success', 'Guard', 'Hi to everyone', /success.png/, { })
        ::Guard::Notifier.notify('Hi to everyone')
      end

      it 'sets the "failed" type for a :failed image' do
        expect(Guard::Notifier::GNTP).to receive(:notify).with('failed', 'Guard', 'Hi to everyone', /failed.png/, { })
        ::Guard::Notifier.notify('Hi to everyone', :image => :failed)
      end

      it 'sets the "pending" type for a :pending image' do
        expect(Guard::Notifier::GNTP).to receive(:notify).with('pending', 'Guard', 'Hi to everyone', /pending.png/, { })
        ::Guard::Notifier.notify('Hi to everyone', :image => :pending)
      end

      it 'sets the "success" type for a :success image' do
        expect(Guard::Notifier::GNTP).to receive(:notify).with('success', 'Guard', 'Hi to everyone', /success.png/, { })
        ::Guard::Notifier.notify('Hi to everyone', :image => :success)
      end

      it 'sets the "notify" type for a custom image' do
        expect(Guard::Notifier::GNTP).to receive(:notify).with('notify', 'Guard', 'Hi to everyone', '/path/to/image.png', { })
        ::Guard::Notifier.notify('Hi to everyone', :image => '/path/to/image.png')
      end

      it 'passes custom options to the notifier' do
        expect(Guard::Notifier::GNTP).to receive(:notify).with('success', 'Guard', 'Hi to everyone', /success.png/, { :param => 'test' })
        ::Guard::Notifier.notify('Hi to everyone', :param => 'test')
      end

      it 'sends the notification to multiple notifier' do
        Guard::Notifier.notifications = [{ :name => :gntp, :options => { } }, { :name => :growl, :options => { } }]
        expect(Guard::Notifier::GNTP).to receive(:notify)
        expect(Guard::Notifier::Growl).to receive(:notify)
        ::Guard::Notifier.notify('Hi to everyone')
      end
    end

    context 'when notifications are disabled' do
      before do
        Guard::Notifier.notifications = [{ :name => :gntp, :options => { } }, { :name => :growl, :options => { } }]
        allow(Guard::Notifier).to receive(:enabled?).and_return false
      end

      it 'does not send any notifications to a notifier' do
        expect(Guard::Notifier::GNTP).not_to receive(:notify)
        expect(Guard::Notifier::Growl).not_to receive(:notify)
        ::Guard::Notifier.notify('Hi to everyone')
      end
    end
  end

end
