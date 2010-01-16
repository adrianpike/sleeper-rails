SLEEPER_DONT_BOOT = true; require(File.dirname(__FILE__) + "/../../../../config/environment") unless defined?(Rails)

require 'test_helper'

class RealWorldTest < Test::Unit::TestCase

	should 'give me all the data with everything on and not hork itself' do
		define_test_models
		
		mysql_connection = {
		    :adapter  => "mysql",
		    :host     => "localhost",
		    :username => "sleeper_test",
		    :password => "sleeper_test",
		    :database => "sleeper_test"
		}
		
		UnkeyedTest.establish_connection(mysql_connection)
		KeyedTest.establish_connection(mysql_connection)
		
		Sleeper.init({
			:sleeper_host=>'http://localhost',
			:log=>STDOUT,
			:client_key=>'foobar',
        	:debug => true,
        	:benchmarking => true,
        	:explaining => true,
        	:traces => true,
        	:profiling => true,
        	:peeking => true,
					:max_update_size => 10000 # 10k
      	}
		)
		
		test_url = '/benchmark_testery/rails'
		
		$POSTED_DATA = []

		browser = Rack::Test::Session.new(Rack::MockSession.new(
		Rack::Builder.new {
 			map "/" do
				run ActionController::Dispatcher.new
 			end
 		}.to_app
		))
		
		browser.get test_url
		
		env = {
			'REQUEST_URI' => 'testing'
		}
		Sleeper.prepare_request(env)
		
		uk=UnkeyedTest.find_all_by_key('foobar')
		u=UnkeyedTest.find_by_key('lol')
		assert u.value
		
		finish_sleeper_test!
		
		assert_equal $POSTED_DATA.length, 1
		first_posted = ActiveSupport::JSON.decode($POSTED_DATA.first['data'])
		
		### Check the basic metrics from the Rack request
		assert_equal first_posted['requests'].size, 2
		assert_equal first_posted['requests'].first['url'], test_url
		assert_not_nil first_posted['requests'].first['view_time']
		assert_not_nil first_posted['requests'].first['database_time']
		assert_equal first_posted['requests'].first['database_time'], 0
		
		### Check the advanced stuff from our faked Rack request
		assert_equal first_posted['requests'].last['url'], 'testing'
		
		### Check out the explanations
		assert_equal first_posted['requests'].last['explained'].length, 2
		assert_not_nil first_posted['requests'].last['explained'].first['query']
		assert_not_nil first_posted['requests'].last['explained'].first['explanation']
		assert_match /ConnectionAdapters::Mysql/, first_posted['requests'].last['explained'].first['connection_adapter']
		assert_equal first_posted['requests'].last['explained'].first['explanation']['select_type'], 'SIMPLE'
		
		### Check out the peeks
		k = first_posted['requests'].last['activerecord_loads'].keys.first
		assert_equal first_posted['requests'].last['activerecord_loads'][k]['attributes'].length, 5
		assert_equal first_posted['requests'].last['activerecord_loads'][k]['read_attributes'].first, 'value'
		assert_equal first_posted['requests'].last['activerecord_loads'][k]['class'], "UnkeyedTest"
		assert_match /attribute_peeker.rb/, first_posted['requests'].last['activerecord_loads'][k]['location'].first
	end

end