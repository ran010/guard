require 'rubygems'
require 'coveralls'
Coveralls.wear!

require 'guard'
require 'guard/ui'
require 'guard/guard'
require 'rspec'

ENV["GUARD_ENV"] = 'test'

Dir["#{File.expand_path('..', __FILE__)}/support/**/*.rb"].each { |f| require f }

puts "Please do not update/create files while tests are running."

RSpec.configure do |config|
  config.color = true
  config.order = :random
  config.filter_run :focus => true
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true

  config.before(:each) do
    @fixture_path = Pathname.new(File.expand_path('../fixtures/', __FILE__))

    # Ensure debug command execution isn't used in the specs
    allow(Guard).to receive(:debug_command_execution)

    # Stub all UI methods, so no visible output appears for the UI class
    allow(::Guard::UI).to receive(:info)
    allow(::Guard::UI).to receive(:warning)
    allow(::Guard::UI).to receive(:error)
    allow(::Guard::UI).to receive(:debug)
    allow(::Guard::UI).to receive(:deprecation)
  end

  config.before(:all) do
    ::Guard::Notifier.send(:auto_detect_notification)

    @guard_notify = ENV['GUARD_NOTIFY']
    @guard_notifications = ::Guard::Notifier.notifications
  end

  config.after(:each) do
    Pry.config.hooks.delete_hook(:when_started, :load_guard_rc)
    Pry.config.hooks.delete_hook(:when_started, :load_project_guard_rc)

    if ::Guard.options
      ::Guard.options[:debug] = false
    end
  end

  config.after(:all) do
    ENV['GUARD_NOTIFY'] = @guard_notify
    ::Guard::Notifier.notifications = @guard_notifications
  end

end
