SLEEPER_DONT_BOOT = true

require 'rubygems'

unless defined?(Rails)
	require 'action_controller'
	require 'action_controller/test_process'
	require 'active_record'
	require 'active_record/base'
	require 'active_support'
	require 'active_support/test_case'
end

Dir.glob(File.join(File.dirname(__FILE__), "..", "lib", "sleeper", "*.rb")).each {|f| require f }
Dir.glob(File.join(File.dirname(__FILE__), "..", "lib", "*.rb")).each {|f| require f }
require 'test/unit'

require 'shoulda'
require 'rack/test'