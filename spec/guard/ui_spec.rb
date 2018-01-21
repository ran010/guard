require 'spec_helper'

describe Guard::UI do
  after { Guard::UI.options = { :level => :info, :device => $stderr, :template => ':time - :severity - :message', :time_format => '%H:%M:%S' } }

  before do
    # The spec helper stubs all UI classes, so other specs doesn't have
    # to explicit take care of it. We unstub and move the stubs one layer
    # down just for this spec.
    allow(Guard::UI).to receive(:info).and_call_original
    allow(Guard::UI).to receive(:warning).and_call_original
    allow(Guard::UI).to receive(:error).and_call_original
    allow(Guard::UI).to receive(:deprecation).and_call_original
    allow(Guard::UI).to receive(:debug).and_call_original

    allow(Guard::UI.logger).to receive(:info)
    allow(Guard::UI.logger).to receive(:warn)
    allow(Guard::UI.logger).to receive(:error)
    allow(Guard::UI.logger).to receive(:deprecation)
    allow(Guard::UI.logger).to receive(:debug)
  end

  after do
    allow(::Guard::UI).to receive(:info)
    allow(::Guard::UI).to receive(:warning)
    allow(::Guard::UI).to receive(:error)
    allow(::Guard::UI).to receive(:debug)
    allow(::Guard::UI).to receive(:deprecation)
  end

  describe '.logger' do
    it 'returns the logger instance' do
      expect(Guard::UI.logger).to be_an_instance_of Lumberjack::Logger
    end

    it 'sets the logger device' do
      expect(Guard::UI.logger.device.send(:stream)).to be $stderr
    end
  end

  describe '.options=' do
    it 'sets the logger options' do
      Guard::UI.options = { :hi => :ho }
      expect(Guard::UI.options).to eql({ :hi => :ho })
    end
  end

  describe '.info' do
    it 'resets the line with the :reset option' do
      expect(Guard::UI).to receive :reset_line
      Guard::UI.info('Info message', { :reset => true })
    end

    it 'logs the message to with the info severity' do
      skip 'See: https://github.com/rspec/rspec-mocks/issues/613'
      expect(Guard::UI.logger).to receive(:info).with('Info message', 'Guard::UiSpec')
      Guard::UI.info 'Info message'
    end

    context 'with the :only option' do
      before { Guard::UI.options[:only] = /A/ }

      it 'shows only the matching messages' do
        expect(Guard::UI.logger).to receive(:info).with('Info message', 'A')
        expect(Guard::UI.logger).not_to receive(:info).with('Info message', 'B')
        expect(Guard::UI.logger).not_to receive(:info).with('Info message', 'C')

        Guard::UI.info 'Info message', :plugin => 'A'
        Guard::UI.info 'Info message', :plugin => 'B'
        Guard::UI.info 'Info message', :plugin => 'C'
      end
    end

    context 'with the :except option' do
      before { Guard::UI.options[:except] = /A/ }

      it 'shows only the matching messages' do
        expect(Guard::UI.logger).not_to receive(:info).with('Info message', 'A')
        expect(Guard::UI.logger).to receive(:info).with('Info message', 'B')
        expect(Guard::UI.logger).to receive(:info).with('Info message', 'C')

        Guard::UI.info 'Info message', :plugin => 'A'
        Guard::UI.info 'Info message', :plugin => 'B'
        Guard::UI.info 'Info message', :plugin => 'C'
      end
    end
  end

  describe '.warning' do
    it 'resets the line with the :reset option' do
      expect(Guard::UI).to receive :reset_line
      Guard::UI.warning('Warn message', { :reset => true })
    end

    it 'logs the message to with the warn severity' do
      skip 'See: https://github.com/rspec/rspec-mocks/issues/613'
      expect(Guard::UI.logger).to receive(:warn).with("\e[0;33mWarn message\e[0m", 'Guard::UiSpec')
      Guard::UI.warning 'Warn message'
    end

    context 'with the :only option' do
      before { Guard::UI.options[:only] = /A/ }

      it 'shows only the matching messages' do
        expect(Guard::UI.logger).to receive(:warn).with("\e[0;33mWarn message\e[0m", 'A')
        expect(Guard::UI.logger).not_to receive(:warn).with("\e[0;33mWarn message\e[0m", 'B')
        expect(Guard::UI.logger).not_to receive(:warn).with("\e[0;33mWarn message\e[0m", 'C')

        Guard::UI.warning 'Warn message', :plugin => 'A'
        Guard::UI.warning 'Warn message', :plugin => 'B'
        Guard::UI.warning 'Warn message', :plugin => 'C'
      end
    end

    context 'with the :except option' do
      before { Guard::UI.options[:except] = /A/ }

      it 'shows only the matching messages' do
        expect(Guard::UI.logger).not_to receive(:warn).with("\e[0;33mWarn message\e[0m", 'A')
        expect(Guard::UI.logger).to receive(:warn).with("\e[0;33mWarn message\e[0m", 'B')
        expect(Guard::UI.logger).to receive(:warn).with("\e[0;33mWarn message\e[0m", 'C')

        Guard::UI.warning 'Warn message', :plugin => 'A'
        Guard::UI.warning 'Warn message', :plugin => 'B'
        Guard::UI.warning 'Warn message', :plugin => 'C'
      end
    end
  end

  describe '.error' do
    it 'resets the line with the :reset option' do
      expect(Guard::UI).to receive :reset_line
      Guard::UI.error('Error message', { :reset => true })
    end

    it 'logs the message to with the error severity' do
      skip 'See: https://github.com/rspec/rspec-mocks/issues/613'
      expect(Guard::UI.logger).to receive(:error).with("\e[0;31mError message\e[0m", 'Guard::UiSpec')
      Guard::UI.error 'Error message'
    end

    context 'with the :only option' do
      before { Guard::UI.options[:only] = /A/ }

      it 'shows only the matching messages' do
        expect(Guard::UI.logger).to receive(:error).with("\e[0;31mError message\e[0m", 'A')
        expect(Guard::UI.logger).not_to receive(:error).with("\e[0;31mError message\e[0m", 'B')
        expect(Guard::UI.logger).not_to receive(:error).with("\e[0;31mError message\e[0m", 'C')

        Guard::UI.error 'Error message', :plugin => 'A'
        Guard::UI.error 'Error message', :plugin => 'B'
        Guard::UI.error 'Error message', :plugin => 'C'
      end
    end

    context 'with the :except option' do
      before { Guard::UI.options[:except] = /A/ }

      it 'shows only the matching messages' do
        expect(Guard::UI.logger).not_to receive(:error).with("\e[0;31mError message\e[0m", 'A')
        expect(Guard::UI.logger).to receive(:error).with("\e[0;31mError message\e[0m", 'B')
        expect(Guard::UI.logger).to receive(:error).with("\e[0;31mError message\e[0m", 'C')

        Guard::UI.error 'Error message', :plugin => 'A'
        Guard::UI.error 'Error message', :plugin => 'B'
        Guard::UI.error 'Error message', :plugin => 'C'
      end
    end
  end

  describe '.deprecation' do
    it 'resets the line with the :reset option' do
      expect(Guard::UI).to receive :reset_line
      Guard::UI.deprecation('Deprecation message', { :reset => true })
    end

    it 'logs the message to with the warn severity' do
      skip 'See: https://github.com/rspec/rspec-mocks/issues/613'
      expect(Guard::UI.logger).to receive(:warn).with("\e[0;33mDeprecation message\e[0m", 'Guard::UiSpec')
      Guard::UI.deprecation 'Deprecation message'
    end

    context 'with the :only option' do
      before { Guard::UI.options[:only] = /A/ }

      it 'shows only the matching messages' do
        expect(Guard::UI.logger).to receive(:warn).with("\e[0;33mDeprecation message\e[0m", 'A')
        expect(Guard::UI.logger).not_to receive(:warn).with("\e[0;33mDeprecation message\e[0m", 'B')
        expect(Guard::UI.logger).not_to receive(:warn).with("\e[0;33mDeprecation message\e[0m", 'C')

        Guard::UI.deprecation 'Deprecation message', :plugin => 'A'
        Guard::UI.deprecation 'Deprecation message', :plugin => 'B'
        Guard::UI.deprecation 'Deprecation message', :plugin => 'C'
      end
    end

    context 'with the :except option' do
      before { Guard::UI.options[:except] = /A/ }

      it 'shows only the matching messages' do
        expect(Guard::UI.logger).not_to receive(:warn).with("\e[0;33mDeprecation message\e[0m", 'A')
        expect(Guard::UI.logger).to receive(:warn).with("\e[0;33mDeprecation message\e[0m", 'B')
        expect(Guard::UI.logger).to receive(:warn).with("\e[0;33mDeprecation message\e[0m", 'C')

        Guard::UI.deprecation 'Deprecation message', :plugin => 'A'
        Guard::UI.deprecation 'Deprecation message', :plugin => 'B'
        Guard::UI.deprecation 'Deprecation message', :plugin => 'C'
      end
    end
  end

  describe '.debug' do
    it 'resets the line with the :reset option' do
      expect(Guard::UI).to receive :reset_line
      Guard::UI.debug('Debug message', { :reset => true })
    end

    it 'logs the message to with the debug severity' do
      skip 'See: https://github.com/rspec/rspec-mocks/issues/613'
      expect(Guard::UI.logger).to receive(:debug).with("\e[0;33mDebug message\e[0m", 'Guard::UiSpec')
      Guard::UI.debug 'Debug message'
    end

    context 'with the :only option' do
      before { Guard::UI.options[:only] = /A/ }

      it 'shows only the matching messages' do
        expect(Guard::UI.logger).to receive(:debug).with("\e[0;33mDebug message\e[0m", 'A')
        expect(Guard::UI.logger).not_to receive(:debug).with("\e[0;33mDebug message\e[0m", 'B')
        expect(Guard::UI.logger).not_to receive(:debug).with("\e[0;33mDebug message\e[0m", 'C')

        Guard::UI.debug 'Debug message', :plugin => 'A'
        Guard::UI.debug 'Debug message', :plugin => 'B'
        Guard::UI.debug 'Debug message', :plugin => 'C'
      end
    end

    context 'with the :except option' do
      before { Guard::UI.options[:except] = /A/ }

      it 'shows only the matching messages' do
        expect(Guard::UI.logger).not_to receive(:debug).with("\e[0;33mDebug message\e[0m", 'A')
        expect(Guard::UI.logger).to receive(:debug).with("\e[0;33mDebug message\e[0m", 'B')
        expect(Guard::UI.logger).to receive(:debug).with("\e[0;33mDebug message\e[0m", 'C')

        Guard::UI.debug 'Debug message', :plugin => 'A'
        Guard::UI.debug 'Debug message', :plugin => 'B'
        Guard::UI.debug 'Debug message', :plugin => 'C'
      end
    end
  end

  describe '.clear' do
    context 'when the Guard clear option is enabled' do
      before { allow(::Guard).to receive(:options) { { :clear => true } } }

      it 'clears the outputs if clearable' do
        Guard::UI.clearable
        expect(Guard::UI).to receive(:system).with('clear;')
        Guard::UI.clear
      end

      it 'doesn not clear the output if already cleared' do
        allow(Guard::UI).to receive(:system)
        Guard::UI.clear
        expect(Guard::UI).not_to receive(:system).with('clear;')
        Guard::UI.clear
      end

      it 'clears the outputs if forced' do
        allow(Guard::UI).to receive(:system)
        Guard::UI.clear
        expect(Guard::UI).to receive(:system).with('clear;')
        Guard::UI.clear(:force => true)
      end
    end

    context 'when the Guard clear option is disabled' do
      before { allow(::Guard).to receive(:options) { { :clear => false } } }

      it 'does not clear the output' do
        expect(Guard::UI).not_to receive(:system).with('clear;')
        Guard::UI.clear
      end
    end
  end

  describe '.action_with_scopes' do
    context 'with a plugins scope' do
      it 'shows the plugin scoped action' do
        expect(Guard::UI).to receive(:info).with('Reload rspec,jasmine')
        Guard::UI.action_with_scopes('Reload', { :plugins => [:rspec, :jasmine] })
      end
    end

    context 'with a groups scope' do
      it 'shows the group scoped action' do
        expect(Guard::UI).to receive(:info).with('Reload frontend')
        Guard::UI.action_with_scopes('Reload', { :groups => [:frontend] })
      end
    end

    context 'without a scope' do
      context 'with a global plugin scope' do
        it 'shows the global plugin scoped action' do
          Guard.scope = { :groups => [:test] }
          expect(Guard::UI).to receive(:info).with('Reload test')
          Guard::UI.action_with_scopes('Reload', {})
        end
      end

      context 'with a global group scope' do
        it 'shows the global group scoped action' do
          Guard.scope = { :groups => [:backend] }
          expect(Guard::UI).to receive(:info).with('Reload backend')
          Guard::UI.action_with_scopes('Reload', {})
        end
      end
    end
  end

end
