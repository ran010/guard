require 'spec_helper'

describe Guard::Notifier::GrowlNotify do

  let(:fake_growl_notify) do
    Class.new do
      def self.application_name; end
      def self.send_notification(options) end
    end
  end

  before do
    allow(subject).to receive(:require)
    stub_const 'GrowlNotify', fake_growl_notify
  end

  describe '.available?' do
    context 'without the silent option' do
      it 'shows an error message when not available on the host OS' do
        expect(::Guard::UI).to receive(:error).with 'The :growl_notify notifier runs only on Mac OS X.'
        expect(RbConfig::CONFIG).to receive(:[]).with('host_os').and_return 'mswin'
        subject.available?
      end

      it 'shows an error message when the gem cannot be loaded' do
        expect(RbConfig::CONFIG).to receive(:[]).with('host_os').and_return 'darwin'
        expect(::Guard::UI).to receive(:error).with "Please add \"gem 'growl_notify'\" to your Gemfile and run Guard with \"bundle exec\"."
        expect(subject).to receive(:require).with('growl_notify').and_raise LoadError
        subject.available?
      end
    end

    context 'with the silent option' do
      it 'does not show an error message when not available on the host OS' do
        expect(::Guard::UI).not_to receive(:error).with 'The :growl_notify notifier runs only on Mac OS X.'
        expect(RbConfig::CONFIG).to receive(:[]).with('host_os').and_return 'mswin'
        subject.available?(true)
      end

      it 'does not show an error message when the gem cannot be loaded' do
        expect(RbConfig::CONFIG).to receive(:[]).with('host_os').and_return 'darwin'
        expect(::Guard::UI).not_to receive(:error).with "Please add \"gem 'growl_notify'\" to your Gemfile and run Guard with \"bundle exec\"."
        expect(subject).to receive(:require).with('growl_notify').and_raise LoadError
        subject.available?(true)
      end
    end

    context 'when the application name is not Guard' do
      let(:config) { double('config') }

      it 'does configure GrowlNotify' do
        expect(RbConfig::CONFIG).to receive(:[]).with('host_os').and_return 'darwin'
        expect(::GrowlNotify).to receive(:application_name).and_return nil
        expect(::GrowlNotify).to receive(:config).and_yield config
        expect(config).to receive(:notifications=).with ['success', 'pending', 'failed', 'notify']
        expect(config).to receive(:default_notifications=).with 'notify'
        expect(config).to receive(:application_name=).with 'Guard'
        subject.available?
      end
    end

    context 'when the application name is Guard' do
      it 'does not configure GrowlNotify again' do
        expect(RbConfig::CONFIG).to receive(:[]).with('host_os').and_return 'darwin'
        expect(::GrowlNotify).to receive(:application_name).and_return 'Guard'
        expect(::GrowlNotify).not_to receive(:config)
        subject.available?
      end
    end

  end

  describe '.nofify' do
    it 'requires the library again' do
      expect(subject).to receive(:require).with('growl_notify').and_return true
      subject.notify('success', 'Welcome', 'Welcome to Guard', '/tmp/welcome.png', { })
    end

    context 'without additional options' do
      it 'shows the notification with the default options' do
        expect(::GrowlNotify).to receive(:send_notification).with({
            :sticky           => false,
            :priority         => 0,
            :application_name => 'Guard',
            :with_name        => 'success',
            :title            => 'Welcome',
            :description      => 'Welcome to Guard',
            :icon             => '/tmp/welcome.png'
        })
        subject.notify('success', 'Welcome', 'Welcome to Guard', '/tmp/welcome.png', { })
      end
    end

    context 'with additional options' do
      it 'can override the default options' do
        expect(::GrowlNotify).to receive(:send_notification).with({
            :sticky           => true,
            :priority         => -2,
            :application_name => 'Guard',
            :with_name        => 'pending',
            :title            => 'Waiting',
            :description      => 'Waiting for something',
            :icon             => '/tmp/wait.png'
        })
        subject.notify('pending', 'Waiting', 'Waiting for something', '/tmp/wait.png', {
            :sticky   => true,
            :priority => -2
        })
      end

      it 'cannot override the core options' do
        expect(::GrowlNotify).to receive(:send_notification).with({
            :sticky           => false,
            :priority         => 0,
            :application_name => 'Guard',
            :with_name        => 'failed',
            :title            => 'Failed',
            :description      => 'Something failed',
            :icon             => '/tmp/fail.png'
        })
        subject.notify('failed', 'Failed', 'Something failed', '/tmp/fail.png', {
            :application_name => 'Guard CoffeeScript',
            :with_name        => 'custom',
            :title            => 'Duplicate title',
            :description      => 'Duplicate description',
            :icon             => 'Duplicate icon'
        })
      end
    end
  end

end
