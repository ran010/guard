# encoding: utf-8

require 'spec_helper'
require 'formatador'

describe Guard::DslDescriber do

  let(:guardfile) do
    <<-GUARDFILE
      ignore! %r{tmp/}
      guard :test, :a => :b, :c => :d do
        watch('c')
      end

      group :a do
        guard 'test', :x => 1, :y => 2 do
          watch('c')
        end
      end

      group "b" do
        guard :another do
          watch('c')
        end
      end
    GUARDFILE
  end

  before do
    stub_const 'Guard::Test', Class.new(Guard::Guard)
    stub_const 'Guard::Another', Class.new(Guard::Guard)

    @output = ''

    # Strip escape sequences
    allow(STDOUT).to receive(:tty?).and_return false

    # Capture formatador output
    Thread.current[:formatador] = Formatador.new
    allow(Thread.current[:formatador]).to receive(:print) do |msg|
      @output << msg
    end
  end

  describe '.list' do
    let(:result) do
      <<-OUTPUT
  +---------+-----------+
  | Plugin  | Guardfile |
  +---------+-----------+
  | Another | ✔         |
  | Even    | ✘         |
  | More    | ✘         |
  | Test    | ✔         |
  +---------+-----------+
      OUTPUT
    end

    before do
      allow(::Guard).to receive(:guard_gem_names).and_return %w(test another even more)
    end

    it 'lists the available Guards when they\'re declared as strings or symbols' do
      ::Guard::DslDescriber.list(:guardfile_contents => guardfile)
      # Drop the calls to delete when drop Ruby 1.8.7 support
      expect(@output.delete(' ')).to eq result.delete(' ')
    end
  end

  describe '.show' do
    let(:result) do
      <<-OUTPUT
  +---------+---------+--------+-------+
  | Group   | Plugin  | Option | Value |
  +---------+---------+--------+-------+
  | Default | Test    | a      | :b    |
  |         |         | c      | :d    |
  +---------+---------+--------+-------+
  | A       | Test    | x      | 1     |
  |         |         | y      | 2     |
  +---------+---------+--------+-------+
  | B       | Another |        |       |
  +---------+---------+--------+-------+
      OUTPUT
    end

    it 'shows the Guards and their options' do
      ::Guard::DslDescriber.show(:guardfile_contents => guardfile)
      expect(@output).to eq result
    end
  end

end
