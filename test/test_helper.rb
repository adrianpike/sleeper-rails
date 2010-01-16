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

$POSTED_DATA = []

module Net
	class HTTP
		def self.post_form(url, content)
			$POSTED_DATA << content

			Net::HTTPResponse.new("fake_http","200",'hooray!')
		end
	end
end

def define_test_models
		Object.class_eval {
			remove_const UnkeyedTest.to_s if defined?(UnkeyedTest)
			const_set('UnkeyedTest', Class.new(ActiveRecord::Base))
			remove_const KeyedTest.to_s if defined?(KeyedTest)
			const_set('KeyedTest', Class.new(ActiveRecord::Base))
		}
end

define_test_models

def prepare_sleeper_test!
	env = {
		'REQUEST_URI' => 'testing'
	}
	Sleeper.prepare_request(env)
	$POSTED_DATA = []
end

def finish_sleeper_test!
	env = {
		'REQUEST_URI' => 'testing'
	}
	Sleeper.finish_request(env)
	Sleeper.statistics.gather_host_data
	Sleeper.statistics.upload!
end