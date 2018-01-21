require 'spec_helper'

describe Guard do
  before do
    allow(::Guard::Interactor).to receive(:fabricate)
    allow(Dir).to receive(:chdir)
  end

  describe ".setup" do
    let(:options) { { :my_opts => true, :guardfile => File.join(@fixture_path, "Guardfile") } }
    subject { ::Guard.setup(options) }

    it "returns itself for chaining" do
      expect(subject).to be ::Guard
    end

    it "initializes the plugins" do
      expect(subject.guards).to eq []
    end

    it "initializes the groups" do
      expect(subject.groups[0].name).to eq :default
      expect(subject.groups[0].options).to eq({ })
    end

    it "initializes the options" do
      expect(subject.options).to include(:my_opts)
    end

    it "initializes the listener" do
      expect(subject.listener).to be_kind_of(Listen::Listener)
    end

    it "respect the watchdir option" do
      ::Guard.setup(:watchdir => '/usr')

      expect(::Guard.listener.directories).to eq ['/usr']
    end

    it "changes the current work dir to the watchdir" do
      expect(Dir).to receive(:chdir).with('/tmp')
      ::Guard.setup(:watchdir => '/tmp')
    end

    it "call setup_signal_traps" do
      expect(::Guard).to receive(:setup_signal_traps)
      subject
    end

    it "evaluates the DSL" do
      expect(::Guard::Dsl).to receive(:evaluate_guardfile).with(options)
      subject
    end

    it "displays an error message when no guard are defined in Guardfile" do
      expect(::Guard::UI).to receive(:error).with('No guards found in Guardfile, please add at least one.')
      subject
    end

    it "call setup_notifier" do
      expect(::Guard).to receive(:setup_notifier)
      subject
    end

    it "call setup_interactor" do
      expect(::Guard).to receive(:setup_interactor)
      subject
    end

    context 'without the group or plugin option' do
      it "initializes the empty scope" do
        expect(subject.scope).to eq({ :groups => [], :plugins => [] })
      end
    end

    context 'with the group option' do
      let(:options) { {
        :group              => ['backend', 'frontend'],
        :guardfile_contents => "group :backend do; end; group :frontend do; end; group :excluded do; end"
      } }

      it "initializes the group scope" do
        expect(subject.scope[:plugins]).to be_empty
        expect(subject.scope[:groups].count).to be 2
        expect(subject.scope[:groups][0].name).to eql :backend
        expect(subject.scope[:groups][1].name).to eql :frontend
      end
    end

    context 'with the plugin option' do
      let(:options) { {
        :plugin             => ['cucumber', 'jasmine'],
        :guardfile_contents => "guard :jasmine do; end; guard :cucumber do; end; guard :coffeescript do; end"
      } }

      before do
        stub_const 'Guard::Jasmine', Class.new(Guard::Guard)
        stub_const 'Guard::Cucumber', Class.new(Guard::Guard)
        stub_const 'Guard::CoffeeScript', Class.new(Guard::Guard)
      end

      it "initializes the plugin scope" do
        expect(subject.scope[:groups]).to be_empty
        expect(subject.scope[:plugins].count).to be 2
        expect(subject.scope[:plugins][0].class).to eql ::Guard::Cucumber
        expect(subject.scope[:plugins][1].class).to eql ::Guard::Jasmine
      end
    end

    context 'when deprecations should be shown' do
      let(:options) { { :show_deprecations => true, :guardfile => File.join(@fixture_path, "Guardfile") } }
      subject { ::Guard.setup(options) }
      let(:runner) { double('runner') }

      it 'calls the runner show deprecations' do
        expect(::Guard::Runner).to receive(:new).and_return runner
        expect(runner).to receive(:deprecation_warning)
        subject
      end
    end

    context 'with the debug mode turned on' do
      let(:options) { { :debug => true, :guardfile => File.join(@fixture_path, "Guardfile") } }
      subject { ::Guard.setup(options) }

      it "logs command execution if the debug option is true" do
        expect(::Guard).to receive(:debug_command_execution)
        subject
      end

      it "sets the log level to :debug if the debug option is true" do
        subject
        expect(::Guard::UI.options[:level]).to eql :debug
      end
    end
  end

  describe ".setup_signal_traps", :speed => 'slow' do
    before { allow(::Guard::Dsl).to receive(:evaluate_guardfile) }

    unless windows? || defined?(JRUBY_VERSION)
      context 'when receiving SIGUSR1' do
        context 'when Guard is running' do
          before { expect(::Guard.listener).to receive(:paused?).and_return false }

          it 'pauses Guard' do
            expect(::Guard).to receive(:pause)
            Process.kill :USR1, Process.pid
            sleep 1
          end
        end

        context 'when Guard is already paused' do
          before { expect(::Guard.listener).to receive(:paused?).and_return true }

          it 'does not pauses Guard' do
            expect(::Guard).not_to receive(:pause)
            Process.kill :USR1, Process.pid
            sleep 1
          end
        end
      end

      context 'when receiving SIGUSR2' do
        context 'when Guard is paused' do
          before { expect(::Guard.listener).to receive(:paused?).and_return true }

          it 'un-pause Guard' do
            expect(::Guard).to receive(:pause)
            Process.kill :USR2, Process.pid
            sleep 1
          end
        end

        context 'when Guard is already running' do
          before { expect(::Guard.listener).to receive(:paused?).and_return false }

          it 'does not un-pause Guard' do
            expect(::Guard).not_to receive(:pause)
            Process.kill :USR2, Process.pid
            sleep 1
          end
        end
      end

      context 'when receiving SIGINT' do
        context 'without an interactor' do
          before { expect(::Guard).to receive(:interactor).and_return nil }

          it 'stops Guard' do
            expect(::Guard).to receive(:stop)
            Process.kill :INT, Process.pid
            sleep 1
          end
        end

        context 'with an interactor' do
          let(:interactor) { double('interactor', :thread => double('thread')) }
          before { expect(::Guard).to receive(:interactor).twice.and_return interactor }

          it 'delegates to the Pry thread' do
            expect(interactor.thread).to receive(:raise).with Interrupt
            Process.kill :INT, Process.pid
            sleep 1
          end
        end
      end
    end

    context "with the notify option enabled" do
      context 'without the environment variable GUARD_NOTIFY set' do
        before { ENV["GUARD_NOTIFY"] = nil }

        it "turns on the notifier on" do
          expect(::Guard::Notifier).to receive(:turn_on)
          ::Guard.setup(:notify => true)
        end
      end

      context 'with the environment variable GUARD_NOTIFY set to true' do
        before { ENV["GUARD_NOTIFY"] = 'true' }

        it "turns on the notifier on" do
          expect(::Guard::Notifier).to receive(:turn_on)
          ::Guard.setup(:notify => true)
        end
      end

      context 'with the environment variable GUARD_NOTIFY set to false' do
        before { ENV["GUARD_NOTIFY"] = 'false' }

        it "turns on the notifier off" do
          expect(::Guard::Notifier).to receive(:turn_off)
          ::Guard.setup(:notify => true)
        end
      end
    end

    context "with the notify option disable" do
      context 'without the environment variable GUARD_NOTIFY set' do
        before { ENV["GUARD_NOTIFY"] = nil }

        it "turns on the notifier off" do
          expect(::Guard::Notifier).to receive(:turn_off)
          ::Guard.setup(:notify => false)
        end
      end

      context 'with the environment variable GUARD_NOTIFY set to true' do
        before { ENV["GUARD_NOTIFY"] = 'true' }

        it "turns on the notifier on" do
          expect(::Guard::Notifier).to receive(:turn_off)
          ::Guard.setup(:notify => false)
        end
      end

      context 'with the environment variable GUARD_NOTIFY set to false' do
        before { ENV["GUARD_NOTIFY"] = 'false' }

        it "turns on the notifier off" do
          expect(::Guard::Notifier).to receive(:turn_off)
          ::Guard.setup(:notify => false)
        end
      end
    end
  end

  describe ".setup_listener" do
    let(:listener) { double.as_null_object }

    context "with latency option" do
      before { allow(::Guard).to receive(:options).and_return("latency" => 1.5) }

      it "pass option to listener" do
        expect(Listen).to receive(:to).with(anything, { :relative_paths => true, :latency => 1.5 }) { listener }
        ::Guard.setup_listener
      end
    end

    context "with force_polling option" do
      before { allow(::Guard).to receive(:options).and_return("force_polling" => true) }

      it "pass option to listener" do
        expect(Listen).to receive(:to).with(anything, { :relative_paths => true, :force_polling => true }) { listener }
        ::Guard.setup_listener
      end
    end
  end

  describe ".setup_notifier" do
    context "with the notify option enabled" do
      before { allow(::Guard).to receive(:options).and_return(:notify => true) }

      context 'without the environment variable GUARD_NOTIFY set' do
        before { ENV["GUARD_NOTIFY"] = nil }

        it_should_behave_like 'notifier enabled'
      end

      context 'with the environment variable GUARD_NOTIFY set to true' do
        before { ENV["GUARD_NOTIFY"] = 'true' }

        it_should_behave_like 'notifier enabled'
      end

      context 'with the environment variable GUARD_NOTIFY set to false' do
        before { ENV["GUARD_NOTIFY"] = 'false' }

        it_should_behave_like 'notifier disabled'
      end
    end

    context "with the notify option disabled" do
      before do
        allow(::Guard).to receive(:options).and_return(:notify => false)
      end

      context 'without the environment variable GUARD_NOTIFY set' do
        before { ENV["GUARD_NOTIFY"] = nil }

        it_should_behave_like 'notifier disabled'
      end

      context 'with the environment variable GUARD_NOTIFY set to true' do
        before { ENV["GUARD_NOTIFY"] = 'true' }

        it_should_behave_like 'notifier disabled'
      end

      context 'with the environment variable GUARD_NOTIFY set to false' do
        before { ENV["GUARD_NOTIFY"] = 'false' }

        it_should_behave_like 'notifier disabled'
      end
    end
  end

  describe ".setup_interactor" do
    context 'with CLI options' do
      before do
        @enabled                    = ::Guard::Interactor.enabled
        ::Guard::Interactor.enabled = true
      end

      after { ::Guard::Interactor.enabled = @enabled }

      context "with interactions enabled" do
        before { ::Guard.setup(:no_interactions => false) }

        it_should_behave_like 'interactor enabled'
      end

      context "with interactions disabled" do
        before { ::Guard.setup(:no_interactions => true) }

        it_should_behave_like 'interactor disabled'
      end
    end

    context 'with DSL options' do
      before { @enabled = ::Guard::Interactor.enabled }
      after { ::Guard::Interactor.enabled = @enabled }

      context "with interactions enabled" do
        before do
          ::Guard::Interactor.enabled = true
          ::Guard.setup()
        end

        it_should_behave_like 'interactor enabled'
      end

      context "with interactions disabled" do
        before do
          ::Guard::Interactor.enabled = false
          ::Guard.setup()
        end

        it_should_behave_like 'interactor disabled'
      end
    end
  end

  describe '#reload' do
    let(:runner) { double(:run => true) }
    subject { ::Guard.setup }

    before do
      allow(::Guard).to receive(:runner) { runner }
      allow(::Guard::Dsl).to receive(:reevaluate_guardfile)
      allow(::Guard).to receive(:within_preserved_state).and_yield
      allow(::Guard::UI).to receive(:info)
      allow(::Guard::UI).to receive(:clear)
    end

    it "clear UI" do
      expect(::Guard::UI).to receive(:clear)
      subject.reload
    end

    context 'with a old scope format' do
      it 'does not re-evaluate the Guardfile' do
        expect(::Guard::Dsl).not_to receive(:reevaluate_guardfile)
        subject.reload({ :group => :frontend })
      end

      it 'reloads Guard' do
        expect(runner).to receive(:run).with(:reload, { :groups => [:frontend] })
        subject.reload({ :group => :frontend })
      end
    end

    context 'with a new scope format' do
      it 'does not re-evaluate the Guardfile' do
        expect(::Guard::Dsl).not_to receive(:reevaluate_guardfile)
        subject.reload({ :groups => [:frontend] })
      end

      it 'reloads Guard' do
        expect(runner).to receive(:run).with(:reload, { :groups => [:frontend] })
        subject.reload({ :groups => [:frontend] })
      end
    end

    context 'with an empty scope' do
      it 'does re-evaluate the Guardfile' do
        expect(::Guard::Dsl).to receive(:reevaluate_guardfile)
        subject.reload
      end

      it 'does not reload Guard' do
        expect(runner).not_to receive(:run).with(:reload, { })
        subject.reload
      end
    end
  end

  describe ".guards" do
    before(:all) do
      class Guard::FooBar < Guard::Guard;
      end
      class Guard::FooBaz < Guard::Guard;
      end
    end

    after(:all) do
      ::Guard.instance_eval do
        remove_const(:FooBar)
        remove_const(:FooBaz)
      end
    end

    subject do
      guard                   = ::Guard.setup
      @guard_foo_bar_backend  = Guard::FooBar.new([], { :group => 'backend' })
      @guard_foo_bar_frontend = Guard::FooBar.new([], { :group => 'frontend' })
      @guard_foo_baz_backend  = Guard::FooBaz.new([], { :group => 'backend' })
      @guard_foo_baz_frontend = Guard::FooBaz.new([], { :group => 'frontend' })
      guard.instance_variable_get("@guards").push(@guard_foo_bar_backend)
      guard.instance_variable_get("@guards").push(@guard_foo_bar_frontend)
      guard.instance_variable_get("@guards").push(@guard_foo_baz_backend)
      guard.instance_variable_get("@guards").push(@guard_foo_baz_frontend)
      guard
    end

    it "return @guards without any argument" do
      expect(subject.guards).to eq(subject.instance_variable_get("@guards"))
    end

    context "find a guard by as string/symbol" do
      it "find a guard by a string" do
        expect(subject.guards('foo-bar')).to eq(@guard_foo_bar_backend)
      end

      it "find a guard by a symbol" do
        expect(subject.guards(:'foo-bar')).to eq(@guard_foo_bar_backend)
      end

      it "returns nil if guard is not found" do
        expect(subject.guards('foo-foo')).to be_nil
      end
    end

    context "find guards matching a regexp" do
      it "with matches" do
        expect(subject.guards(/^foobar/)).to eq([@guard_foo_bar_backend, @guard_foo_bar_frontend])
      end

      it "without matches" do
        expect(subject.guards(/foo$/)).to eq([])
      end
    end

    context "find guards by their group" do
      it "group name is a string" do
        expect(subject.guards(:group => 'backend')).to eq([@guard_foo_bar_backend, @guard_foo_baz_backend])
      end

      it "group name is a symbol" do
        expect(subject.guards(:group => :frontend)).to eq([@guard_foo_bar_frontend, @guard_foo_baz_frontend])
      end

      it "returns [] if guard is not found" do
        expect(subject.guards(:group => :unknown)).to eq([])
      end
    end

    context "find guards by their group & name" do
      it "group name is a string" do
        expect(subject.guards(:group => 'backend', :name => 'foo-bar')).to eq([@guard_foo_bar_backend])
      end

      it "group name is a symbol" do
        expect(subject.guards(:group => :frontend, :name => :'foo-baz')).to eq([@guard_foo_baz_frontend])
      end

      it "returns [] if guard is not found" do
        expect(subject.guards(:group => :unknown, :name => :'foo-baz')).to eq([])
      end
    end
  end

  describe ".groups" do
    subject do
      guard           = ::Guard.setup
      @group_backend  = guard.add_group(:backend)
      @group_backflip = guard.add_group(:backflip)
      guard
    end

    context 'without any argument' do
      it "return all groups" do
        expect(subject.groups).to eq(subject.instance_variable_get("@groups"))
      end
    end

    context "find a group by as string/symbol" do
      it "find a group by a string" do
        expect(subject.groups('backend')).to eq(@group_backend)
      end

      it "find a group by a symbol" do
        expect(subject.groups(:backend)).to eq(@group_backend)
      end

      it "returns nil if group is not found" do
        expect(subject.groups(:foo)).to be_nil
      end
    end

    context "find groups matching a regexp" do
      it "with matches" do
        expect(subject.groups(/^back/)).to eq([@group_backend, @group_backflip])
      end

      it "without matches" do
        expect(subject.groups(/back$/)).to eq([])
      end
    end
  end

  describe ".setup_groups" do
    subject do
      guard           = ::Guard.setup(:guardfile => File.join(@fixture_path, "Guardfile"))
      @group_backend  = guard.add_group(:backend)
      @group_backflip = guard.add_group(:backflip)
      guard
    end

    it "initializes a default group" do
      subject.setup_groups

      expect(subject.groups.size).to eq(1)
      expect(subject.groups[0].name).to eq :default
      expect(subject.groups[0].options).to eq({ })
    end
  end

  describe ".setup_guards" do
    before(:all) {
      class Guard::FooBar < Guard::Guard;
      end }

    after(:all) do
      ::Guard.instance_eval { remove_const(:FooBar) }
    end

    subject do
      guard          = ::Guard.setup(:guardfile => File.join(@fixture_path, "Guardfile"))
      @group_backend = guard.add_guard(:foo_bar)
      guard
    end

    it "return @guards without any argument" do
      expect(subject.guards.size).to eq(1)

      subject.setup_guards

      expect(subject.guards).to be_empty
    end
  end

  describe ".start" do
    before do
      allow(::Guard).to receive(:setup)
      allow(::Guard).to receive(:listener).and_return(double('listener', :start => true))
      allow(::Guard).to receive(:runner).and_return(double('runner', :run => true))
      allow(::Guard).to receive(:within_preserved_state).and_yield
    end

    it "setup Guard" do
      expect(::Guard).to receive(:setup).with(:foo => 'bar')

      ::Guard.start(:foo => 'bar')
    end

    it "displays an info message" do
      ::Guard.instance_variable_set('@watchdir', '/foo/bar')
      expect(::Guard::UI).to receive(:info).with("Guard is now watching at '/foo/bar'")

      ::Guard.start
    end

    it "tell the runner to run the :start task" do
      expect(::Guard.runner).to receive(:run).with(:start)

      ::Guard.start
    end

    it "start the listener" do
      expect(::Guard.listener).to receive(:start)

      ::Guard.start
    end
  end

  describe ".stop" do
    before do
      allow(::Guard).to receive(:setup)
      allow(::Guard).to receive(:listener).and_return(double('listener', :stop => true))
      allow(::Guard).to receive(:runner).and_return(double('runner', :run => true))
      allow(::Guard).to receive(:within_preserved_state).and_yield
    end

    it "turns the notifier off" do
      expect(::Guard::Notifier).to receive(:turn_off)

      ::Guard.stop
    end

    it "tell the runner to run the :stop task" do
      expect(::Guard.runner).to receive(:run).with(:stop)

      ::Guard.stop
    end

    it "stops the listener" do
      expect(::Guard.listener).to receive(:stop)

      ::Guard.stop
    end

    it "sets the running state to false" do
      ::Guard.running = true
      ::Guard.stop
      expect(::Guard.running).to be_falsey
    end
  end

  describe ".add_guard" do
    before do
      @guard_rspec_class = double('Guard::RSpec')
      @guard_rspec       = double('Guard::RSpec', :is_a? => true)

      allow(::Guard).to receive(:get_guard_class) { @guard_rspec_class }

      ::Guard.setup_guards
      ::Guard.setup_groups
      ::Guard.add_group(:backend)
    end

    it "accepts guard name as string" do
      expect(@guard_rspec_class).to receive(:new).and_return(@guard_rspec)

      ::Guard.add_guard('rspec')
    end

    it "accepts guard name as symbol" do
      expect(@guard_rspec_class).to receive(:new).and_return(@guard_rspec)

      ::Guard.add_guard(:rspec)
    end

    it "adds guard to the @guards array" do
      expect(@guard_rspec_class).to receive(:new).and_return(@guard_rspec)

      ::Guard.add_guard(:rspec)

      expect(::Guard.guards).to eq [@guard_rspec]
    end

    context "with no watchers given" do
      it "gives an empty array of watchers" do
        expect(@guard_rspec_class).to receive(:new).with([], { }).and_return(@guard_rspec)

        ::Guard.add_guard(:rspec, [])
      end
    end

    context "with watchers given" do
      it "give the watchers array" do
        expect(@guard_rspec_class).to receive(:new).with([:foo], { }).and_return(@guard_rspec)

        ::Guard.add_guard(:rspec, [:foo])
      end
    end

    context "with no options given" do
      it "gives an empty hash of options" do
        expect(@guard_rspec_class).to receive(:new).with([], { }).and_return(@guard_rspec)

        ::Guard.add_guard(:rspec, [], [], { })
      end
    end

    context "with options given" do
      it "give the options hash" do
        expect(@guard_rspec_class).to receive(:new).with([], { :foo => true, :group => :backend }).and_return(@guard_rspec)

        ::Guard.add_guard(:rspec, [], [], { :foo => true, :group => :backend })
      end
    end
  end

  describe ".add_group" do
    before { ::Guard.setup_groups }

    it "accepts group name as string" do
      ::Guard.add_group('backend')

      expect(::Guard.groups[0].name).to eq(:default)
      expect(::Guard.groups[1].name).to eq(:backend)
    end

    it "accepts group name as symbol" do
      ::Guard.add_group(:backend)

      expect(::Guard.groups[0].name).to eq(:default)
      expect(::Guard.groups[1].name).to eq(:backend)
    end

    it "accepts options" do
      ::Guard.add_group(:backend, { :halt_on_fail => true })

      expect(::Guard.groups[0].options).to eq({ })
      expect(::Guard.groups[1].options).to eq({ :halt_on_fail => true })
    end
  end

  describe '.within_preserved_state' do
    subject { ::Guard.setup }
    before { subject.interactor = double('interactor').as_null_object }

    it 'disallows running the block concurrently to avoid inconsistent states' do
      expect(subject.lock).to receive(:synchronize)
      subject.within_preserved_state &Proc.new { }
    end

    it 'runs the passed block' do
      @called = false
      subject.within_preserved_state { @called = true }
      expect(@called).to be_truthy
    end

    context 'with restart interactor enabled' do
      it 'stops the interactor before running the block and starts it again when done' do
        expect(subject.interactor).to receive(:stop)
        expect(subject.interactor).to receive(:start)
        subject.within_preserved_state &Proc.new { }
      end
    end

    context 'without restart interactor enabled' do
      it 'stops the interactor before running the block' do
        expect(subject.interactor).to receive(:stop)
        subject.interactor.should__not_receive(:start)
        subject.within_preserved_state &Proc.new { }
      end
    end
  end

  describe ".get_guard_class" do
    after do
      [:Classname, :DashedClassName, :UnderscoreClassName, :VSpec, :Inline].each do |const|
        Guard.send(:remove_const, const) rescue nil
      end
    end

    it "reports an error if the class is not found" do
      expect(::Guard::UI).to receive(:error).twice
      Guard.get_guard_class('notAGuardClass')
    end

    context 'with a nested Guard class' do
      after(:all) { Guard.instance_eval { remove_const(:Classname) } rescue nil }

      it "resolves the Guard class from string" do
        expect(Guard).to receive(:require) { |classname|
          expect(classname).to eq 'guard/classname'
          class Guard::Classname;
          end
        }
        expect(Guard.get_guard_class('classname')).to eq(Guard::Classname)
      end

      it "resolves the Guard class from symbol" do
        expect(Guard).to receive(:require) { |classname|
          expect(classname).to eq 'guard/classname'
          class Guard::Classname;
          end
        }
        expect(Guard.get_guard_class(:classname)).to eq(Guard::Classname)
      end
    end

    context 'with a name with dashes' do
      after(:all) { Guard.instance_eval { remove_const(:DashedClassName) } rescue nil }

      it "returns the Guard class" do
        expect(Guard).to receive(:require) { |classname|
          expect(classname).to eq 'guard/dashed-class-name'
          class Guard::DashedClassName;
          end
        }
        expect(Guard.get_guard_class('dashed-class-name')).to eq(Guard::DashedClassName)
      end
    end

    context 'with a name with underscores' do
      after(:all) { Guard.instance_eval { remove_const(:UnderscoreClassName) } rescue nil }

      it "returns the Guard class" do
        expect(Guard).to receive(:require) { |classname|
          expect(classname).to eq 'guard/underscore_class_name'
          class Guard::UnderscoreClassName;
          end
        }
        expect(Guard.get_guard_class('underscore_class_name')).to eq(Guard::UnderscoreClassName)
      end
    end

    context 'with a name where its class does not follow the strict case rules' do
      after(:all) { Guard.instance_eval { remove_const(:VSpec) } rescue nil }

      it "returns the Guard class" do
        expect(Guard).to receive(:require) { |classname|
          expect(classname).to eq 'guard/vspec'
          class Guard::VSpec;
          end
        }
        expect(Guard.get_guard_class('vspec')).to eq(Guard::VSpec)
      end
    end

    context 'with an inline Guard class' do
      after(:all) { Guard.instance_eval { remove_const(:Inline) } rescue nil }

      it 'returns the Guard class' do
        module Guard
          class Inline < Guard
          end
        end

        expect(Guard).not_to receive(:require)
        expect(Guard.get_guard_class('inline')).to eq(Guard::Inline)
      end
    end

    context 'when set to fail gracefully' do
      it 'does not print error messages on fail' do
        expect(::Guard::UI).not_to receive(:error)
        expect(Guard.get_guard_class('notAGuardClass', true)).to be_nil
      end
    end
  end

  let!(:rubygems_version_1_7_2) { Gem::Version.create('1.7.2') }
  let!(:rubygems_version_1_8_0) { Gem::Version.create('1.8.0') }

  describe '.locate_guard' do
    context 'Rubygems < 1.8.0' do
      before do
        expect(Gem::Version).to receive(:create).with(Gem::VERSION) { rubygems_version_1_7_2 }
        expect(Gem::Version).to receive(:create).with('1.8.0') { rubygems_version_1_8_0 }
      end

      it "returns the path of a Guard gem" do
        gems_source_index = double
        gems_found = [double(:full_gem_path => 'gems/guard-rspec')]
        expect(Gem).to receive(:source_index) { gems_source_index }
        expect(gems_source_index).to receive(:find_name).with('guard-rspec') { gems_found }

        expect(Guard.locate_guard('rspec')).to eq 'gems/guard-rspec'
      end
    end

    context 'Rubygems >= 1.8.0' do
      before do
        expect(Gem::Version).to receive(:create).with(Gem::VERSION) { rubygems_version_1_8_0 }
        expect(Gem::Version).to receive(:create).with('1.8.0') { rubygems_version_1_8_0 }
      end

      it "returns the path of a Guard gem" do
        expect(Gem::Specification).to receive(:find_by_name).with('guard-rspec') { double(:full_gem_path => 'gems/guard-rspec') }

        expect(Guard.locate_guard('rspec')).to eq 'gems/guard-rspec'
      end
    end
  end

  describe '.guard_gem_names' do
    context 'Rubygems < 1.8.0' do
      before do
        expect(Gem::Version).to receive(:create).with(Gem::VERSION) { rubygems_version_1_7_2 }
        expect(Gem::Version).to receive(:create).with('1.8.0') { rubygems_version_1_8_0 }
        gems_source_index = double
        expect(Gem).to receive(:source_index) { gems_source_index }
        expect(gems_source_index).to receive(:find_name).with(/^guard-/) { [double(:name => 'guard-rspec')] }
      end

      it 'returns the list of guard gems' do
        expect(Guard.guard_gem_names).to include('rspec')
      end
    end

    context 'Rubygems >= 1.8.0' do
      before do
        expect(Gem::Version).to receive(:create).with(Gem::VERSION) { rubygems_version_1_8_0 }
        expect(Gem::Version).to receive(:create).with('1.8.0') { rubygems_version_1_8_0 }
        gems = [
          double(:name => 'guard'),
          double(:name => 'guard-rspec'),
          double(:name => 'gem1', :full_gem_path => '/gem1'),
          double(:name => 'gem2', :full_gem_path => '/gem2'),
        ]
        allow(File).to receive(:exists?).with('/gem1/lib/guard/gem1.rb') { false }
        allow(File).to receive(:exists?).with('/gem2/lib/guard/gem2.rb') { true }
        expect(Gem::Specification).to receive(:find_all) { gems }
      end

      it "returns the list of guard gems" do
        gems = Guard.guard_gem_names
        expect(gems).to include('rspec')
      end

      it "returns the list of embedded guard gems" do
        gems = Guard.guard_gem_names
        expect(gems).to include('gem2')
      end
    end
  end

  describe ".debug_command_execution" do
    subject { ::Guard.setup }

    before do
      allow(Guard).to receive(:debug_command_execution).and_call_original
      @original_system  = Kernel.method(:system)
      @original_command = Kernel.method(:"`")
    end

    after do
      Kernel.send(:remove_method, :system, :'`')
      Kernel.send(:define_method, :system, @original_system.to_proc)
      Kernel.send(:define_method, :"`", @original_command.to_proc)
      allow(Guard).to receive(:debug_command_execution)
    end

    it "outputs Kernel.#system method parameters" do
      expect(::Guard::UI).to receive(:debug).with("Command execution: exit 0")
      ::Guard.setup(:debug => true)
      expect(system("exit", "0")).to be_falsey
    end

    it "outputs Kernel.#` method parameters" do
      expect(::Guard::UI).to receive(:debug).with("Command execution: echo test")
      ::Guard.setup(:debug => true)
      expect(`echo test`).to eq("test\n")
    end

    it "outputs %x{} method parameters" do
      expect(::Guard::UI).to receive(:debug).with("Command execution: echo test")
      ::Guard.setup(:debug => true)
      expect(%x{echo test}).to eq("test\n")
    end

  end

  describe ".deprecated_options_warning" do
    subject { ::Guard.setup }

    context "with watch_all_modifications options" do
      before { subject.options[:watch_all_modifications] = true }

      it 'displays a deprecation warning to the user' do
        expect(::Guard::UI).to receive(:deprecation)
        subject.deprecated_options_warning
      end
    end

    context "with no_vendor options" do
      before { subject.options[:no_vendor] = true }

      it 'displays a deprecation warning to the user' do
        expect(::Guard::UI).to receive(:deprecation)
        subject.deprecated_options_warning
      end
    end

  end

end
