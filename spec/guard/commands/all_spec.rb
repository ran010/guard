require 'spec_helper'

describe 'Guard::Interactor::ALL' do

  let(:guard)     { ::Guard.setup }
  let(:foo_group) { guard.add_group(:foo) }
  let(:bar_guard) { guard.add_guard(:bar, [], [], { :group => :foo }) }

  before do
    allow(Guard).to receive(:run_all)
    allow(Guard).to receive(:setup_interactor)
    allow(Pry.output).to receive(:puts)
    stub_const 'Guard::Bar', Class.new(Guard::Guard)
  end

  describe '#perform' do
    context 'without scope' do
      it 'runs the :run_all action' do
        expect(Guard).to receive(:run_all).with({ :groups => [], :plugins => [] })
        Pry.run_command 'all'
      end
    end

    context 'with a valid Guard group scope' do
      it 'runs the :run_all action with the given scope' do
        expect(Guard).to receive(:run_all).with({ :groups => [foo_group], :plugins => [] })
        Pry.run_command 'all foo'
      end
    end

    context 'with a valid Guard plugin scope' do
      it 'runs the :run_all action with the given scope' do
        expect(Guard).to receive(:run_all).with({ :plugins => [bar_guard], :groups => [] })
        Pry.run_command 'all bar'
      end
    end

    context 'with an invalid scope' do
      it 'does not run the action' do
        expect(Guard).not_to receive(:run_all)
        Pry.run_command 'all baz'
      end
    end
  end
end
