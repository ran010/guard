require 'spec_helper'

describe Guard::Guardfile do

  it "has a valid Guardfile template" do
    expect(File.exists?(Guard::GUARDFILE_TEMPLATE)).to be_truthy
  end

  describe ".create_guardfile" do
    before { allow(Dir).to receive(:pwd).and_return "/home/user" }

    context "with an existing Guardfile" do
      before { expect(File).to receive(:exist?).and_return true }

      it "does not copy the Guardfile template or notify the user" do
        expect(::Guard::UI).not_to receive(:info)
        expect(FileUtils).not_to receive(:cp)

        described_class.create_guardfile
      end

      it "does not display any kind of error or abort" do
        expect(::Guard::UI).not_to receive(:error)
        expect(described_class).not_to receive(:abort)
        described_class.create_guardfile
      end

      context "with the :abort_on_existence option set to true" do
        it "displays an error message and aborts the process" do
          expect(::Guard::UI).to receive(:error).with("Guardfile already exists at /home/user/Guardfile")
          expect(described_class).to receive(:abort)
          described_class.create_guardfile(:abort_on_existence => true)
        end
      end
    end

    context "without an existing Guardfile" do
      before { expect(File).to receive(:exist?).and_return false }

      it "copies the Guardfile template and notifies the user" do
        expect(::Guard::UI).to receive(:info)
        expect(FileUtils).to receive(:cp)

        described_class.create_guardfile
      end
    end
  end

  describe ".duplicate_defintions?" do
    context "that finds an existing Guardfile"  do
      context "that has duplicate definitions" do
        it "should return true" do
          io = StringIO.new("guard 'rspec' do\nend\nguard 'rspec' do\nend\n")
          expect(Guard::Guardfile.duplicate_definitions?('rspec', io.string)).to eq(true)
        end
      end

      context "that doesn't have duplicate definitions" do
        it "should return false" do
          io = StringIO.new("guard 'rspec' do\nend\n")
          expect(Guard::Guardfile.duplicate_definitions?('rspec', io.string)).to eq(false)
        end
      end
    end
  end

  describe ".initialize_template" do
    context 'with an installed Guard implementation' do
      let(:foo_guard) { double('Guard::Foo').as_null_object }

      before { expect(::Guard).to receive(:get_guard_class).and_return(foo_guard) }

      it "initializes the Guard" do
        expect(foo_guard).to receive(:init)
        described_class.initialize_template('foo')
      end
    end

    context "with a user defined template" do
      let(:template) { File.join(Guard::HOME_TEMPLATES, '/bar') }

      before { expect(File).to receive(:exist?).with(template).and_return true }

      it "copies the Guardfile template and initializes the Guard" do
        expect(File).to receive(:read).with('Guardfile').and_return 'Guardfile content'
        expect(File).to receive(:read).with(template).and_return 'Template content'
        io = StringIO.new
        expect(File).to receive(:open).with('Guardfile', 'wb').and_yield io
        described_class.initialize_template('bar')
        expect(io.string).to eq("Guardfile content\n\nTemplate content\n")
      end
    end

    context "when the passed guard can't be found" do
      before do
        expect(::Guard).to receive(:get_guard_class).and_return nil
        expect(File).to receive(:exist?).and_return false
      end

      it "notifies the user about the problem" do
        expect(::Guard::UI).to receive(:error).with(
          "Could not load 'guard/foo' or '~/.guard/templates/foo' or find class Guard::Foo"
        )
        described_class.initialize_template('foo')
      end
    end
  end

  describe ".initialize_all_templates" do
    let(:guards) { ['rspec', 'spork', 'phpunit'] }

    before { expect(::Guard).to receive(:guard_gem_names).and_return(guards) }

    it "calls Guard.initialize_template on all installed guards" do
      guards.each do |g|
        expect(described_class).to receive(:initialize_template).with(g)
      end

      described_class.initialize_all_templates
    end
  end

end
