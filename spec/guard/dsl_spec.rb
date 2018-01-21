require 'spec_helper'

describe Guard::Dsl do

  before do
    @local_guardfile_path = File.join(Dir.pwd, 'Guardfile')
    @home_guardfile_path  = File.expand_path(File.join('~', '.Guardfile'))
    @user_config_path     = File.expand_path(File.join('~', '.guard.rb'))

    stub_const 'Guard::Dummy', Class.new(Guard::Guard)

    allow(::Guard).to receive(:setup_interactor)

    ::Guard.setup

    allow(::Guard).to receive(:options).and_return(:debug => true)
    allow(::Guard).to receive(:guards).and_return([double('Guard')])

    allow(::Guard::Notifier).to receive(:notify)
  end

  def self.disable_user_config
    before(:each) { allow(File).to receive(:exist?).with(@user_config_path) { false } }
  end

  describe 'it should select the correct data source for Guardfile' do
    before(:each) { allow(::Guard::Dsl).to receive(:instance_eval_guardfile) }
    disable_user_config

    it 'should use a string for initializing' do
      expect(Guard::UI).not_to receive(:error)
      expect { described_class.evaluate_guardfile(:guardfile_contents => valid_guardfile_string) }.not_to raise_error
      expect(described_class.guardfile_contents).to eq(valid_guardfile_string)
    end

    it 'should use a given file over the default loc' do
      fake_guardfile('/abc/Guardfile', 'guard :foo')

      expect(Guard::UI).not_to receive(:error)
      expect { described_class.evaluate_guardfile(:guardfile => '/abc/Guardfile') }.not_to raise_error
      expect(described_class.guardfile_contents).to eq('guard :foo')
    end

    it 'should use a default file if no other options are given' do
      fake_guardfile(@local_guardfile_path, 'guard :bar')

      expect(Guard::UI).not_to receive(:error)
      expect { described_class.evaluate_guardfile }.not_to raise_error
      expect(described_class.guardfile_contents).to eq('guard :bar')
    end

    it 'should use a string over any other method' do
      fake_guardfile('/abc/Guardfile', 'guard :foo')
      fake_guardfile(@local_guardfile_path, 'guard :bar')

      expect(Guard::UI).not_to receive(:error)
      expect { described_class.evaluate_guardfile(:guardfile_contents => valid_guardfile_string) }.not_to raise_error
      expect(described_class.guardfile_contents).to eq(valid_guardfile_string)
    end

    it 'should use the given Guardfile over default Guardfile' do
      fake_guardfile('/abc/Guardfile', 'guard :foo')
      fake_guardfile(@local_guardfile_path, 'guard :bar')

      expect(Guard::UI).not_to receive(:error)
      expect { described_class.evaluate_guardfile(:guardfile => '/abc/Guardfile') }.not_to raise_error
      expect(described_class.guardfile_contents).to eq('guard :foo')
    end

    it 'should append the user config file if present' do
      fake_guardfile('/abc/Guardfile', 'guard :foo')
      fake_guardfile(@user_config_path, 'guard :bar')
      expect(Guard::UI).not_to receive(:error)
      expect { described_class.evaluate_guardfile(:guardfile => '/abc/Guardfile') }.not_to raise_error
      expect(described_class.guardfile_contents_with_user_config).to eq("guard :foo\nguard :bar")
    end

  end

  it 'displays an error message when no Guardfile is found' do
    allow(described_class).to receive(:guardfile_default_path).and_return('no_guardfile_here')
    expect(Guard::UI).to receive(:error).with('No Guardfile found, please create one with `guard init`.')
    expect { described_class.evaluate_guardfile }.to raise_error
  end

  it 'doesn\'t display an error message when no Guard plugins are defined in Guardfile' do
    allow(::Guard::Dsl).to receive(:instance_eval_guardfile)
    allow(::Guard).to receive(:guards).and_return([])
    expect(Guard::UI).not_to receive(:error)
    described_class.evaluate_guardfile(:guardfile_contents => valid_guardfile_string)
  end

  describe 'correctly reads data from its valid data source' do
    before(:each) { allow(::Guard::Dsl).to receive(:instance_eval_guardfile) }
    disable_user_config

    it 'reads correctly from a string' do
      expect { described_class.evaluate_guardfile(:guardfile_contents => valid_guardfile_string) }.not_to raise_error
      expect(described_class.guardfile_contents).to eq(valid_guardfile_string)
    end

    it 'reads correctly from a Guardfile' do
      fake_guardfile('/abc/Guardfile', 'guard :foo')

      expect { described_class.evaluate_guardfile(:guardfile => '/abc/Guardfile') }.not_to raise_error
      expect(described_class.guardfile_contents).to eq('guard :foo')
    end

    it 'reads correctly from a Guardfile' do
      fake_guardfile(File.join(Dir.pwd, 'Guardfile'), valid_guardfile_string)

      expect { described_class.evaluate_guardfile }.not_to raise_error
      expect(described_class.guardfile_contents).to eq(valid_guardfile_string)
    end
  end

  describe 'correctly throws errors when initializing with invalid data' do
    before(:each) { allow(::Guard::Dsl).to receive(:instance_eval_guardfile) }

    it 'raises error when there\'s a problem reading a file' do
      allow(File).to receive(:exist?).with('/def/Guardfile') { true }
      allow(File).to receive(:read).with('/def/Guardfile')   { raise Errno::EACCES.new('permission error') }

      expect(Guard::UI).to receive(:error).with(/^Error reading file/)
      expect { described_class.evaluate_guardfile(:guardfile => '/def/Guardfile') }.to raise_error
    end

    it 'raises error when given Guardfile doesn\'t exist' do
      allow(File).to receive(:exist?).with('/def/Guardfile') { false }

      expect(Guard::UI).to receive(:error).with(/No Guardfile exists at/)
      expect { described_class.evaluate_guardfile(:guardfile => '/def/Guardfile') }.to raise_error
    end

    it 'raises error when resorting to use default, finds no default' do
      allow(File).to receive(:exist?).with(@local_guardfile_path) { false }
      allow(File).to receive(:exist?).with(@home_guardfile_path) { false }

      expect(Guard::UI).to receive(:error).with('No Guardfile found, please create one with `guard init`.')
      expect { described_class.evaluate_guardfile }.to raise_error
    end

    it 'raises error when guardfile_content ends up empty or nil' do
      expect(Guard::UI).to receive(:error).with('No Guard plugins found in Guardfile, please add at least one.')
      described_class.evaluate_guardfile(:guardfile_contents => '')
    end

    it 'doesn\'t raise error when guardfile_content is nil (skipped)' do
      expect(Guard::UI).not_to receive(:error)
      expect { described_class.evaluate_guardfile(:guardfile_contents => nil) }.not_to raise_error
    end
  end

  it 'displays an error message when Guardfile is not valid' do
    expect(Guard::UI).to receive(:error).with(/Invalid Guardfile, original error is:/)

    described_class.evaluate_guardfile(:guardfile_contents => invalid_guardfile_string )
  end

  describe '.reevaluate_guardfile' do
    before(:each) { allow(::Guard::Dsl).to receive(:instance_eval_guardfile) }

    it 'executes the before hook' do
      expect(::Guard::Dsl).to receive(:evaluate_guardfile)
      described_class.reevaluate_guardfile
    end

    it 'evaluates the Guardfile' do
      expect(::Guard::Dsl).to receive(:before_reevaluate_guardfile)
      described_class.reevaluate_guardfile
    end

    it 'executes the after hook' do
      expect(::Guard::Dsl).to receive(:after_reevaluate_guardfile)
      described_class.reevaluate_guardfile
    end
  end

  describe '.before_reevaluate_guardfile' do
    it 'stops all Guards' do
      expect(::Guard.runner).to receive(:run).with(:stop)

      described_class.before_reevaluate_guardfile
    end

    it 'clears all Guards' do
      expect(::Guard.guards).not_to be_empty

      described_class.reevaluate_guardfile

      expect(::Guard.guards).to be_empty
    end

    it 'resets all groups' do
      expect(::Guard.groups).not_to be_empty

      described_class.before_reevaluate_guardfile

      expect(::Guard.groups).not_to be_empty
      expect(::Guard.groups[0].name).to eq :default
      expect(::Guard.groups[0].options).to eq({})
    end

    it 'clears the notifications' do
       ::Guard::Notifier.turn_off
       ::Guard::Notifier.notifications = [{ :name => :growl }]
       expect(::Guard::Notifier.notifications).not_to be_empty

       described_class.before_reevaluate_guardfile

       expect(::Guard::Notifier.notifications).to be_empty
    end

    it 'removes the cached Guardfile content' do
      expect(::Guard::Dsl).to receive(:after_reevaluate_guardfile)

      described_class.after_reevaluate_guardfile
    end
  end

  describe '.after_reevaluate_guardfile' do
    context 'with notifications enabled' do
      before { allow(::Guard::Notifier).to receive(:enabled?).and_return true }

      it 'enables the notifications again' do
        expect(::Guard::Notifier).to receive(:turn_on)
        described_class.after_reevaluate_guardfile
      end
    end

    context 'with notifications disabled' do
      before { allow(::Guard::Notifier).to receive(:enabled?).and_return false }

      it 'does not enable the notifications again' do
        expect(::Guard::Notifier).not_to receive(:turn_on)
        described_class.after_reevaluate_guardfile
      end
    end

    context 'with Guards afterwards' do
      it 'shows a success message' do
        allow(::Guard.runner).to receive(:run)

        expect(::Guard::UI).to receive(:info).with('Guardfile has been re-evaluated.')
        described_class.after_reevaluate_guardfile
      end

      it 'shows a success notification' do
        expect(::Guard::Notifier).to receive(:notify).with('Guardfile has been re-evaluated.', :title => 'Guard re-evaluate')
        described_class.after_reevaluate_guardfile
      end

      it 'starts all Guards' do
        expect(::Guard.runner).to receive(:run).with(:start)

        described_class.after_reevaluate_guardfile
      end
    end

    context 'without Guards afterwards' do
      before { allow(::Guard).to receive(:guards).and_return([]) }

      it 'shows a failure notification' do
        expect(::Guard::Notifier).to receive(:notify).with('No guards found in Guardfile, please add at least one.', :title => 'Guard re-evaluate', :image => :failed)
        described_class.after_reevaluate_guardfile
      end
    end
  end

  describe '.guardfile_default_path' do
    let(:local_path) { File.join(Dir.pwd, 'Guardfile') }
    let(:user_path) { File.expand_path(File.join("~", '.Guardfile')) }
    before(:each) { allow(File).to receive(:exist?).and_return(false) }

    context 'when there is a local Guardfile' do
      it 'returns the path to the local Guardfile' do
        allow(File).to receive(:exist?).with(local_path).and_return(true)
        expect(described_class.guardfile_default_path).to eq(local_path)
      end
    end

    context 'when there is a Guardfile in the user\'s home directory' do
      it 'returns the path to the user Guardfile' do
        allow(File).to receive(:exist?).with(user_path).and_return(true)
        expect(described_class.guardfile_default_path).to eq(user_path)
      end
    end

    context 'when there\'s both a local and user Guardfile' do
      it 'returns the path to the local Guardfile' do
        allow(File).to receive(:exist?).with(local_path).and_return(true)
        allow(File).to receive(:exist?).with(user_path).and_return(true)
        expect(described_class.guardfile_default_path).to eq(local_path)
      end
    end
  end

  describe '.guardfile_include?' do
    it 'detects a guard specified by a string with double quotes' do
      allow(described_class).to receive(:guardfile_contents).and_return('guard "test" {watch("c")}')

      expect(described_class.guardfile_include?('test')).to be_truthy
    end

    it 'detects a guard specified by a string with single quote' do
      allow(described_class).to receive(:guardfile_contents).and_return('guard \'test\' {watch("c")}')

      expect(described_class.guardfile_include?('test')).to be_truthy
    end

    it 'detects a guard specified by a symbol' do
      allow(described_class).to receive(:guardfile_contents).and_return('guard :test {watch("c")}')

      expect(described_class.guardfile_include?('test')).to be_truthy
    end

    it 'detects a guard wrapped in parentheses' do
      allow(described_class).to receive(:guardfile_contents).and_return('guard(:test) {watch("c")}')

      expect(described_class.guardfile_include?('test')).to be_truthy
    end
  end

  describe '#ignore_paths' do
    disable_user_config

    it 'adds the paths to the listener\'s ignore_paths' do
      expect(::Guard::UI).to receive(:deprecation).with(described_class::IGNORE_PATHS_DEPRECATION)

      described_class.evaluate_guardfile(:guardfile_contents => 'ignore_paths \'foo\', \'bar\'')
    end
  end

  describe '#ignore' do
    disable_user_config
    let(:listener) { double }

    it 'add ignored regexps to the listener' do
      allow(::Guard).to receive(:listener) { listener }
      expect(::Guard.listener).to receive(:ignore).with(/^foo/,/bar/) { listener }
      expect(::Guard).to receive(:listener=).with(listener)

      described_class.evaluate_guardfile(:guardfile_contents => 'ignore %r{^foo}, /bar/')
    end
  end

  describe '#ignore!' do
    disable_user_config
    let(:listener) { double }

    it 'replace ignored regexps in the listener' do
      allow(::Guard).to receive(:listener) { listener }
      expect(::Guard.listener).to receive(:ignore!).with(/^foo/,/bar/) { listener }
      expect(::Guard).to receive(:listener=).with(listener)

      described_class.evaluate_guardfile(:guardfile_contents => 'ignore! %r{^foo}, /bar/')
    end
  end

  describe '#filter' do
    disable_user_config
    let(:listener) { double }

    it 'add ignored regexps to the listener' do
      allow(::Guard).to receive(:listener) { listener }
      expect(::Guard.listener).to receive(:filter).with(/.txt$/, /.*.zip/) { listener }
      expect(::Guard).to receive(:listener=).with(listener)

      described_class.evaluate_guardfile(:guardfile_contents => 'filter %r{.txt$}, /.*.zip/')
    end
  end

  describe '#filter!' do
    disable_user_config
    let(:listener) { double }

    it 'replace ignored regexps in the listener' do
      allow(::Guard).to receive(:listener) { listener }
      expect(::Guard.listener).to receive(:filter!).with(/.txt$/, /.*.zip/) { listener }
      expect(::Guard).to receive(:listener=).with(listener)

      described_class.evaluate_guardfile(:guardfile_contents => 'filter! %r{.txt$}, /.*.zip/')
    end
  end

  describe '#notification' do
    disable_user_config

    it 'adds a notification to the notifier' do
      expect(::Guard::Notifier).to receive(:add_notification).with(:growl, {}, false)
      described_class.evaluate_guardfile(:guardfile_contents => 'notification :growl')
    end

    it 'adds multiple notification to the notifier' do
      expect(::Guard::Notifier).to receive(:add_notification).with(:growl, {}, false)
      expect(::Guard::Notifier).to receive(:add_notification).with(:ruby_gntp, { :host => '192.168.1.5' }, false)
      described_class.evaluate_guardfile(:guardfile_contents => "notification :growl\nnotification :ruby_gntp, :host => '192.168.1.5'")
    end
  end

  describe '#interactor' do
    disable_user_config

    it 'disables the interactions with :off' do
      expect(::Guard::UI).not_to receive(:deprecation).with(described_class::INTERACTOR_DEPRECATION)
      described_class.evaluate_guardfile(:guardfile_contents => 'interactor :off')
      expect(Guard::Interactor.enabled).to be_falsey
    end

    it 'shows a deprecation for symbols other than :off' do
      expect(::Guard::UI).to receive(:deprecation).with(described_class::INTERACTOR_DEPRECATION)
      described_class.evaluate_guardfile(:guardfile_contents => 'interactor :coolline')
    end

    it 'passes the options to the interactor' do
      expect(::Guard::UI).not_to receive(:deprecation).with(described_class::INTERACTOR_DEPRECATION)
      described_class.evaluate_guardfile(:guardfile_contents => 'interactor :option1 => \'a\', :option2 => 123')
      expect(Guard::Interactor.options).to include({ :option1 => 'a', :option2 => 123 })
    end
  end

  describe '#group' do
    disable_user_config

    it 'evaluates all groups' do
      expect(::Guard).to receive(:add_guard).with('pow', [], [], { :group => :default })
      expect(::Guard).to receive(:add_guard).with('test', [], [], { :group => :w })
      expect(::Guard).to receive(:add_guard).with('rspec', [], [], { :group => :x })
      expect(::Guard).to receive(:add_guard).with('ronn', [], [], { :group => :x })
      expect(::Guard).to receive(:add_guard).with('less', [], [], { :group => :y })

      described_class.evaluate_guardfile(:guardfile_contents => valid_guardfile_string)
    end
  end

  describe '#guard' do
    disable_user_config

    it 'loads a guard specified as a quoted string from the DSL' do
      expect(::Guard).to receive(:add_guard).with('test', [], [], { :group => :default })

      described_class.evaluate_guardfile(:guardfile_contents => 'guard \'test\'')
    end

    it 'loads a guard specified as a double quoted string from the DSL' do
      expect(::Guard).to receive(:add_guard).with('test', [], [], { :group => :default })

      described_class.evaluate_guardfile(:guardfile_contents => 'guard "test"')
    end

    it 'loads a guard specified as a symbol from the DSL' do
      expect(::Guard).to receive(:add_guard).with('test', [], [], { :group => :default })

      described_class.evaluate_guardfile(:guardfile_contents => 'guard :test')
    end

    it 'loads a guard specified as a symbol and called with parens from the DSL' do
      expect(::Guard).to receive(:add_guard).with('test', [], [], { :group => :default })

      described_class.evaluate_guardfile(:guardfile_contents => 'guard(:test)')
    end

    it 'receives options when specified, from normal arg' do
      expect(::Guard).to receive(:add_guard).with('test', [], [], { :opt_a => 1, :opt_b => 'fancy', :group => :default })

      described_class.evaluate_guardfile(:guardfile_contents => 'guard \'test\', :opt_a => 1, :opt_b => \'fancy\'')
    end
  end

  describe '#watch' do
    disable_user_config

    it 'should receive watchers when specified' do
      expect(::Guard).to receive(:add_guard).with('dummy', anything, anything, { :group => :default }) do |_, watchers, _, _|
        expect(watchers.size).to eq 2
        expect(watchers[0].pattern).to eq 'a'
        expect(watchers[0].action.call).to eq proc { 'b' }.call
        expect(watchers[1].pattern).to eq 'c'
        expect(watchers[1].action).to be_nil
      end
      described_class.evaluate_guardfile(:guardfile_contents => '
      guard :dummy do
         watch(\'a\') { \'b\' }
         watch(\'c\')
      end')
    end
  end

  describe '#callback' do
    it 'creates callbacks for the guard' do
      class MyCustomCallback
        def self.call(guard_class, event, args)
          # do nothing
        end
      end

      expect(::Guard).to receive(:add_guard).with('dummy', anything, anything, { :group => :default }) do |name, watchers, callbacks, options|
        expect(callbacks.size).to eq(2)
        expect(callbacks[0][:events]).to    eq :start_end
        expect(callbacks[0][:listener].call(Guard::Dummy, :start_end, 'foo')).to eq 'Guard::Dummy executed \'start_end\' hook with foo!'
        expect(callbacks[1][:events]).to eq [:start_begin, :run_all_begin]
        expect(callbacks[1][:listener]).to eq MyCustomCallback
      end
      described_class.evaluate_guardfile(:guardfile_contents => '
        guard :dummy do
          callback(:start_end) { |guard_class, event, args| "#{guard_class} executed \'#{event}\' hook with #{args}!" }
          callback(MyCustomCallback, [:start_begin, :run_all_begin])
        end')
    end
  end

  describe '#logger' do
    after { Guard::UI.options = { :level => :info, :template => ':time - :severity - :message', :time_format => '%H:%M:%S' } }

    context 'with valid options' do
      it 'sets the logger log level' do
        described_class.evaluate_guardfile(:guardfile_contents => 'logger :level => :error')
        expect(Guard::UI.options[:level]).to eql :error
      end

      it 'sets the logger log level and convert to a symbol' do
        described_class.evaluate_guardfile(:guardfile_contents => 'logger :level => \'error\'')
        expect(Guard::UI.options[:level]).to eql :error
      end

      it 'sets the logger template' do
        described_class.evaluate_guardfile(:guardfile_contents => 'logger :template => \':message - :severity\'')
        expect(Guard::UI.options[:template]).to eql ':message - :severity'
      end

      it 'sets the logger time format' do
        described_class.evaluate_guardfile(:guardfile_contents => 'logger :time_format => \'%Y\'')
        expect(Guard::UI.options[:time_format]).to eql '%Y'
      end

      it 'sets the logger only filter from a symbol' do
        described_class.evaluate_guardfile(:guardfile_contents => 'logger :only => :cucumber')
        expect(Guard::UI.options[:only]).to eql(/cucumber/i)
      end

      it 'sets the logger only filter from a string' do
        described_class.evaluate_guardfile(:guardfile_contents => 'logger :only => \'jasmine\'')
        expect(Guard::UI.options[:only]).to eql(/jasmine/i)
      end

      it 'sets the logger only filter from an array of symbols and string' do
        described_class.evaluate_guardfile(:guardfile_contents => 'logger :only => [:rspec, \'cucumber\']')
        expect(Guard::UI.options[:only]).to eql(/rspec|cucumber/i)
      end

      it 'sets the logger except filter from a symbol' do
        described_class.evaluate_guardfile(:guardfile_contents => 'logger :except => :jasmine')
        expect(Guard::UI.options[:except]).to eql(/jasmine/i)
      end

      it 'sets the logger except filter from a string' do
        described_class.evaluate_guardfile(:guardfile_contents => 'logger :except => \'jasmine\'')
        expect(Guard::UI.options[:except]).to eql(/jasmine/i)
      end

      it 'sets the logger except filter from an array of symbols and string' do
        described_class.evaluate_guardfile(:guardfile_contents => 'logger :except => [:rspec, \'cucumber\', :jasmine]')
        expect(Guard::UI.options[:except]).to eql(/rspec|cucumber|jasmine/i)
      end
    end

    context 'with invalid options' do
      context 'for the log level' do
        it 'shows a warning' do
          expect(Guard::UI).to receive(:warning).with 'Invalid log level `baz` ignored. Please use either :debug, :info, :warn or :error.'
          described_class.evaluate_guardfile(:guardfile_contents => 'logger :level => :baz')
        end

        it 'does not set the invalid value' do
          described_class.evaluate_guardfile(:guardfile_contents => 'logger :level => :baz')
          expect(Guard::UI.options[:level]).to eql :info
        end
      end

      context 'when having both the :only and :except options' do
        it 'shows a warning' do
          expect(Guard::UI).to receive(:warning).with 'You cannot specify the logger options :only and :except at the same time.'
          described_class.evaluate_guardfile(:guardfile_contents => 'logger :only => :jasmine, :except => :rspec')
        end

        it 'removes the options' do
          described_class.evaluate_guardfile(:guardfile_contents => 'logger :only => :jasmine, :except => :rspec')
          expect(Guard::UI.options[:only]).to be_nil
          expect(Guard::UI.options[:except]).to be_nil
        end
      end

    end
  end

  describe '#scope' do
    context 'with an existing command line plugin scope' do
      before do
        ::Guard.options[:plugin] = ['rspec']
        ::Guard.options[:group] = []
      end

      it 'does not use the DSL scope plugin' do
        described_class.evaluate_guardfile(:guardfile_contents => 'scope :plugin => :baz')
        expect(::Guard.options[:plugin]).to eql(['rspec'])
      end

      it 'does not use the DSL scope plugins' do
        described_class.evaluate_guardfile(:guardfile_contents => 'scope :plugins => [:foo, :bar]')
        expect(::Guard.options[:plugin]).to eql(['rspec'])
      end
    end

    context 'without an existing command line plugin scope' do
      before do
        ::Guard.options[:plugin] = []
        ::Guard.options[:group] = []
      end

      it 'does use the DSL scope plugin' do
        described_class.evaluate_guardfile(:guardfile_contents => 'scope :plugin => :baz')
        expect(::Guard.options[:plugin]).to eql([:baz])
      end

      it 'does use the DSL scope plugins' do
        described_class.evaluate_guardfile(:guardfile_contents => 'scope :plugins => [:foo, :bar]')
        expect(::Guard.options[:plugin]).to eql([:foo, :bar])
      end
    end

    context 'with an existing command line group scope' do
      before do
        ::Guard.options[:plugin] = []
        ::Guard.options[:group] = ['frontend']
      end

      it 'does not use the DSL scope plugin' do
        described_class.evaluate_guardfile(:guardfile_contents => 'scope :group => :baz')
        expect(::Guard.options[:group]).to eql(['frontend'])
      end

      it 'does not use the DSL scope plugins' do
        described_class.evaluate_guardfile(:guardfile_contents => 'scope :groups => [:foo, :bar]')
        expect(::Guard.options[:group]).to eql(['frontend'])
      end
    end

    context 'without an existing command line group scope' do
      before do
        ::Guard.options[:plugin] = []
        ::Guard.options[:group] = []
      end

      it 'does use the DSL scope group' do
        described_class.evaluate_guardfile(:guardfile_contents => 'scope :group => :baz')
        expect(::Guard.options[:group]).to eql([:baz])
      end

      it 'does use the DSL scope groups' do
        described_class.evaluate_guardfile(:guardfile_contents => 'scope :groups => [:foo, :bar]')
        expect(::Guard.options[:group]).to eql([:foo, :bar])
      end
    end
  end

  private

  def fake_guardfile(name, contents)
    allow(File).to receive(:exist?).with(name) { true }
    allow(File).to receive(:read).with(name)   { contents }
  end

  def valid_guardfile_string
    '
    notification :growl

    guard :pow

    group :w do
      guard :test
    end

    group :x, :halt_on_fail => true do
      guard :rspec
      guard :ronn
    end

    group :y do
      guard :less
    end
    '
  end

  def invalid_guardfile_string
    'Bad Guardfile'
  end
end
