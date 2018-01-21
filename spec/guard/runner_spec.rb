require 'spec_helper'

describe Guard::Runner do

  let(:guard_module)    { ::Guard }
  let(:ui_module)       { guard_module::UI }
  let(:guard_singleton) { guard_module.setup }

  # One guard in one group
  let!(:foo_group) { guard_singleton.add_group(:foo) }

  let!(:foo_guard) do
    stub_const 'Guard::Foo', Class.new(Guard::Guard)
    guard_singleton.add_guard(:foo, [], [], :group => :foo)
  end

  # Two guards in one group
  let!(:bar_group)  { guard_singleton.add_group(:bar) }

  let!(:bar1_guard) do
    stub_const 'Guard::Bar1', Class.new(Guard::Guard)
    guard_singleton.add_guard(:bar1, [], [], :group => :bar)
  end

  let!(:bar2_guard) do
    stub_const 'Guard::Bar2', Class.new(Guard::Guard)
    guard_singleton.add_guard(:bar2, [], [], :group => :bar)
  end

  before do
    # Stub the groups to avoid using the real ones from Guardfile (ex.: Guard::Rspec)
    allow(guard_module).to receive(:groups) { [foo_group, bar_group] }
  end

  describe '#deprecation_warning' do
    before { allow(guard_module).to receive(:guards) { [foo_guard] } }

    context 'when neither run_on_change nor run_on_deletion is implemented in a guard' do
      it 'does not display a deprecation warning to the user' do
        expect(ui_module).not_to receive(:deprecation)
        subject.deprecation_warning
      end
    end

    context 'when run_on_change is implemented in a guard' do
      before { allow(foo_guard).to receive(:run_on_change) }

      it 'displays a deprecation warning to the user' do
        expect(ui_module).to receive(:deprecation).with(
          described_class::RUN_ON_CHANGE_DEPRECATION % foo_guard.class.name
        )
        subject.deprecation_warning
      end
    end

    context 'when run_on_deletion is implemented in a guard' do
      before { allow(foo_guard).to receive(:run_on_deletion) }

      it 'displays a deprecation warning to the user' do
        expect(ui_module).to receive(:deprecation).with(
          described_class::RUN_ON_DELETION_DEPRECATION % foo_guard.class.name
        )
        subject.deprecation_warning
      end
    end
  end

  describe '#run' do
    let(:scopes) { { :group => foo_group } }

    it 'executes a supervised task on all registered guards implementing that task' do
      [foo_guard, bar1_guard].each do |g|
        allow(g).to receive(:my_task)
        expect(subject).to receive(:run_supervised_task).with(g, :my_task)
      end
      subject.run(:my_task)
    end

    it 'marks an action as unit of work' do
      expect(Lumberjack).to receive(:unit_of_work)
      subject.run(:my_task)
    end

    context 'with a failing task' do
      before { allow(subject).to receive(:run_supervised_task) { throw :task_has_failed } }

      it 'catches the thrown symbol' do
        expect {
          subject.run(:failing)
        }.to_not throw_symbol(:task_has_failed)
      end
    end

    context 'within the scope of a specified local guard' do
      let(:scopes) { { :plugins => [bar1_guard] } }

      it 'executes the supervised task on the specified guard only' do
        allow(bar1_guard).to receive(:my_task)
        expect(subject).to receive(:run_supervised_task).with(bar1_guard, :my_task)

        expect(subject).not_to receive(:run_supervised_task).with(foo_guard, :my_task)
        expect(subject).not_to receive(:run_supervised_task).with(bar2_guard, :my_task)

        subject.run(:my_task, scopes)
      end
    end

    context 'within the scope of a specified local group' do
      let(:scopes) { { :groups => [foo_group] } }

      it 'executes the task on each guard in the specified group only' do
        allow(foo_guard).to receive(:my_task)
        expect(subject).to receive(:run_supervised_task).with(foo_guard, :my_task)

        expect(subject).not_to receive(:run_supervised_task).with(bar1_guard, :my_task)
        expect(subject).not_to receive(:run_supervised_task).with(bar2_guard, :my_task)

        subject.run(:my_task, scopes)
      end
    end
  end

  describe '#run_on_changes' do
    let(:changes) { [ [], [], [] ] }
    let(:watcher_module) { ::Guard::Watcher }

    before do
      allow(subject).to receive(:scoped_guards).and_yield(foo_guard)
      allow(subject).to receive(:clearable?) { false }
      allow(watcher_module).to receive(:match_files) { [] }
    end

    it "always calls UI.clearable" do
      expect(Guard::UI).to receive(:clearable)
      subject.run_on_changes(*changes)
    end

    context 'when clearable' do
      before { allow(subject).to receive(:clearable?) { true } }

      it "clear UI" do
        expect(Guard::UI).to receive(:clear)
        subject.run_on_changes(*changes)
      end
    end

    context 'with no changes' do
      it 'does not run any task' do
        %w[run_on_modifications run_on_change run_on_additions run_on_removals run_on_deletion].each do |task|
          expect(foo_guard).not_to receive(task.to_sym)
        end
        subject.run_on_changes(*changes)
      end
    end

    context "with modified files but modified paths is empty" do
      let(:modified) { %w[file.txt image.png] }

      before do
        changes[0] = modified
        expect(watcher_module).to receive(:match_files).once.with(foo_guard, modified).and_return([])
      end

      it 'does not call run_first_task_found' do
        expect(subject).not_to receive(:run_first_task_found)
        subject.run_on_changes(*changes)
      end
    end

    context 'with modified paths' do
      let(:modified) { %w[file.txt image.png] }

      before do
        changes[0] = modified
        expect(watcher_module).to receive(:match_files).with(foo_guard, modified).and_return(modified)
      end

      it 'executes the :run_first_task_found task' do
        expect(subject).to receive(:run_first_task_found).with(foo_guard, [:run_on_modifications, :run_on_changes, :run_on_change], modified)
        subject.run_on_changes(*changes)
      end
    end

    context "with added files but added paths is empty" do
      let(:added) { %w[file.txt image.png] }

      before do
        changes[0] = added
        expect(watcher_module).to receive(:match_files).once.with(foo_guard, added).and_return([])
      end

      it 'does not call run_first_task_found' do
        expect(subject).not_to receive(:run_first_task_found)
        subject.run_on_changes(*changes)
      end
    end

    context 'with added paths' do
      let(:added) { %w[file.txt image.png] }

      before do
        changes[1] = added
        expect(watcher_module).to receive(:match_files).with(foo_guard, added).and_return(added)
      end

      it 'executes the :run_on_additions task' do
        expect(subject).to receive(:run_first_task_found).with(foo_guard, [:run_on_additions, :run_on_changes, :run_on_change], added)
        subject.run_on_changes(*changes)
      end
    end

    context "with removed files but removed paths is empty" do
      let(:removed) { %w[file.txt image.png] }

      before do
        changes[0] = removed
        expect(watcher_module).to receive(:match_files).once.with(foo_guard, removed).and_return([])
      end

      it 'does not call run_first_task_found' do
        expect(subject).not_to receive(:run_first_task_found)
        subject.run_on_changes(*changes)
      end
    end

    context 'with removed paths' do
      let(:removed) { %w[file.txt image.png] }

      before do
        changes[2] = removed
        expect(watcher_module).to receive(:match_files).with(foo_guard, removed).and_return(removed)
      end

      it 'executes the :run_on_removals task' do
        expect(subject).to receive(:run_first_task_found).with(foo_guard, [:run_on_removals, :run_on_changes, :run_on_deletion], removed)
        subject.run_on_changes(*changes)
      end
    end
  end

  describe '#run_supervised_task' do
    before { allow(guard_module).to receive(:groups).and_call_original }

    it 'executes the task on the passed guard' do
      expect(foo_guard).to receive(:my_task)
      subject.run_supervised_task(foo_guard, :my_task)
    end

    context 'with a task that succeeds' do
      context 'without any arguments' do
        before do
          allow(foo_guard).to receive(:regular_without_arg) { true }
        end

        it 'does not remove the Guard' do
          expect {
            subject.run_supervised_task(foo_guard, :regular_without_arg)
          }.to_not change(guard_singleton.guards, :size)
        end

        it 'returns the result of the task' do
          expect(subject.run_supervised_task(foo_guard, :regular_without_arg)).to be_truthy
        end

        it 'passes the args to the :begin hook' do
          expect(foo_guard).to receive(:hook).with('regular_without_arg_begin', 'given_path')
          subject.run_supervised_task(foo_guard, :regular_without_arg, 'given_path')
        end

        it 'passes the result of the supervised method to the :end hook'  do
          expect(foo_guard).to receive(:hook).with('regular_without_arg_begin', 'given_path')
          expect(foo_guard).to receive(:hook).with('regular_without_arg_end', true)
          subject.run_supervised_task(foo_guard, :regular_without_arg, 'given_path')
        end
      end

      context 'with arguments' do
        before do
          allow(foo_guard).to receive(:regular_with_arg).with('given_path') { "I'm a success" }
        end

        it 'does not remove the Guard' do
          expect {
            subject.run_supervised_task(foo_guard, :regular_with_arg, 'given_path')
          }.to_not change(guard_module.guards, :size)
        end

        it 'returns the result of the task' do
          expect(subject.run_supervised_task(foo_guard, :regular_with_arg, "given_path")).to eq("I'm a success")
        end

        it 'calls the default begin hook but not the default end hook' do
          expect(foo_guard).to receive(:hook).with('failing_begin')
          expect(foo_guard).not_to receive(:hook).with('failing_end')
          subject.run_supervised_task(foo_guard, :failing)
        end
      end
    end

    context 'with a task that throws :task_has_failed' do
      before { allow(foo_guard).to receive(:failing) { throw :task_has_failed } }

      context 'for a guard in group that has the :halt_on_fail option set to true' do
        before { foo_group.options[:halt_on_fail] = true }

        it 'throws :task_has_failed' do
          expect {
            subject.run_supervised_task(foo_guard, :failing)
          }.to throw_symbol(:task_has_failed)
        end
      end

      context 'for a guard in a group that has the :halt_on_fail option set to false' do
        before { foo_group.options[:halt_on_fail] = false }

        it 'catches :task_has_failed' do
          expect {
            subject.run_supervised_task(foo_guard, :failing)
          }.to_not throw_symbol(:task_has_failed)
        end
      end
    end

    context 'with a task that raises an exception' do
      before { allow(foo_guard).to receive(:failing) { raise 'I break your system' } }

      it 'removes the Guard' do
        expect {
          subject.run_supervised_task(foo_guard, :failing)
        }.to change(guard_module.guards, :size).by(-1)

        expect(guard_module.guards).not_to include(foo_guard)
      end

      it 'display an error to the user' do
        expect(ui_module).to receive :error
        expect(ui_module).to receive :info

        subject.run_supervised_task(foo_guard, :failing)
      end

      it 'returns the exception' do
        failing_result = subject.run_supervised_task(foo_guard, :failing)
        expect(failing_result).to be_kind_of(Exception)
        expect(failing_result.message).to eq('I break your system')
      end
    end
  end

  describe '.stopping_symbol_for' do
    let(:guard_implmentation) { double(Guard::Guard).as_null_object }

    it 'returns :task_has_failed when the group is missing' do
      expect(described_class.stopping_symbol_for(guard_implmentation)).to eq(:task_has_failed)
    end

    context 'for a group with :halt_on_fail' do
      let(:group) { double(Guard::Group) }

      before do
        allow(guard_implmentation).to receive(:group).and_return :foo
        allow(group).to receive(:options).and_return({ :halt_on_fail => true })
      end

      it 'returns :no_catch' do
        expect(guard_module).to receive(:groups).with(:foo).and_return group
        expect(described_class.stopping_symbol_for(guard_implmentation)).to eq(:no_catch)
      end
    end

    context 'for a group without :halt_on_fail' do
      let(:group) { double(Guard::Group) }

      before do
        allow(guard_implmentation).to receive(:group).and_return :foo
        allow(group).to receive(:options).and_return({ :halt_on_fail => false })
      end

      it 'returns :task_has_failed' do
        expect(guard_module).to receive(:groups).with(:foo).and_return group
        expect(described_class.stopping_symbol_for(guard_implmentation)).to eq(:task_has_failed)
      end
    end
  end

end
