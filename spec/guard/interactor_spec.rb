require 'spec_helper'

describe Guard::Interactor do

  describe '.convert_scope' do
    before do
      guard           = ::Guard.setup

      stub_const 'Guard::Foo', Class.new(Guard::Guard)
      stub_const 'Guard::Bar', Class.new(Guard::Guard)

      @backend_group  = guard.add_group(:backend)
      @frontend_group = guard.add_group(:frontend)
      @foo_guard      = guard.add_guard(:foo, [], [], { :group => :backend })
      @bar_guard      = guard.add_guard(:bar, [], [], { :group => :frontend })
    end

    it 'returns a group scope' do
      scopes, _ = Guard::Interactor.convert_scope %w(backend)
      expect(scopes).to eql({ :groups => [@backend_group], :plugins => [] })
      scopes, _ = Guard::Interactor.convert_scope %w(frontend)
      expect(scopes).to eql({ :groups => [@frontend_group], :plugins => [] })
    end

    it 'returns a plugin scope' do
      scopes, _ = Guard::Interactor.convert_scope %w(foo)
      expect(scopes).to eql({ :plugins => [@foo_guard], :groups => [] })
      scopes, _ = Guard::Interactor.convert_scope %w(bar)
      expect(scopes).to eql({ :plugins => [@bar_guard], :groups => [] })
    end

    it 'returns multiple group scopes' do
      scopes, _ = Guard::Interactor.convert_scope %w(backend frontend)
      expect(scopes).to eql({ :groups => [@backend_group, @frontend_group], :plugins => [] })
    end

    it 'returns multiple plugin scopes' do
      scopes, _ = Guard::Interactor.convert_scope %w(foo bar)
      expect(scopes).to eql({ :plugins => [@foo_guard, @bar_guard], :groups => [] })
    end

    it 'returns a plugin and group scope' do
      scopes, _ = Guard::Interactor.convert_scope %w(foo backend)
      expect(scopes).to eql({ :plugins => [@foo_guard], :groups => [@backend_group] })
    end

    it 'returns the unkown scopes' do
      _, unkown = Guard::Interactor.convert_scope %w(unkown scope)
      expect(unkown).to eql %w(unkown scope)
    end

  end
end
