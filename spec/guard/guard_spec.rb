require 'spec_helper'

describe Guard::Guard do

  describe '#initialize' do

    it 'assigns the defined watchers' do
      watchers = [ Guard::Watcher.new('*') ]
      guard = Guard::Guard.new(watchers)
      expect(guard.watchers).to eq(watchers)
    end

    it 'assigns the defined options' do
      options = { :a => 1, :b => 2 }
      guard = Guard::Guard.new([], options)
      expect(guard.options).to eq(options)
    end

    context 'with a group in the options' do
      it 'assigns the given group' do
        options = { :group => :test }
        guard = Guard::Guard.new([], options)
        expect(guard.group).to eq(:test)
      end
    end

    context 'without a group in the options' do
      it 'assigns a default group' do
        options = { }
        guard = Guard::Guard.new([], options)
        expect(guard.group).to eq(:default)
      end
    end
  end

  describe '#init' do
    context 'when the Guard is already in the Guardfile' do
      before { allow(::Guard::Dsl).to receive(:guardfile_include?).and_return true }

      it 'shows an info message' do
        expect(::Guard::UI).to receive(:info).with 'Guardfile already includes myguard guard'
        Guard::Guard.init('myguard')
      end
    end

    context 'when the Guard is not in the Guardfile' do
      before { allow(::Guard::Dsl).to receive(:guardfile_include?).and_return false }

      it 'appends the template to the Guardfile' do
        expect(File).to receive(:read).with('Guardfile').and_return 'Guardfile content'
        expect(::Guard).to receive(:locate_guard).with('myguard').and_return '/Users/me/projects/guard-myguard'
        expect(File).to receive(:read).with('/Users/me/projects/guard-myguard/lib/guard/myguard/templates/Guardfile').and_return('Template content')
        io = StringIO.new
        expect(File).to receive(:open).with('Guardfile', 'wb').and_yield io
        Guard::Guard.init('myguard')
        expect(io.string).to eq("Guardfile content\n\nTemplate content\n")
      end
    end
  end

  describe '#to_s' do
    before(:all) { class Guard::Dummy < Guard::Guard; end }

    it "output the short plugin name" do
      guard = Guard::Dummy.new
      expect(guard.to_s).to eq "Dummy"
    end
  end

end
