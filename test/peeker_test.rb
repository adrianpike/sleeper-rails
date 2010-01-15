SLEEPER_DONT_BOOT = true

require(File.dirname(__FILE__) + "/../../../../config/environment") unless defined?(Rails)

require 'test_helper'

module Net
	class HTTP
		def self.post_form(url, content)
			$POSTED_DATA << content

			Net::HTTPResponse.new("fake_http","200",'hooray!')
		end
	end
end


class PeekerTest < Test::Unit::TestCase

	class UnkeyedTest < ActiveRecord::Base;	end
	
	context 'with AttributePeeker turned on' do
		setup do
			Sleeper.init({
				:sleeper_host=>'http://localhost',
				:log=>STDOUT,
				:client_key=>'foobar',
	        	:debug => true,
	        	:benchmarking => false,
	        	:explaining => false,
	        	:traces => false,
	        	:profiling => false,
	        	:peeking => true,
						:max_update_size => 10000 # 10k
	      	}
			)
			
			mysql_connection = {
			    :adapter  => "mysql",
			    :host     => "localhost",
			    :username => "sleeper_test",
			    :password => "sleeper_test",
			    :database => "sleeper_test"
			}
			
			UnkeyedTest.establish_connection(mysql_connection)
			
			UnkeyedTest.delete_all
			
			UnkeyedTest.create({
				:key => 'lol',
				:value => 'testing'
			})
		end
		
		should 'recognize used columns through the accessor functions' do
			
			u=UnkeyedTest.find_by_key('lol')
			
			foo = u.value
			
			env = {
				'REQUEST_URI' => 'testing'
			}
			
			$POSTED_DATA = []
				
			Sleeper.finish_request(env)
			Sleeper.statistics.gather_host_data
			Sleeper.statistics.upload!
			
			
			assert_equal $POSTED_DATA.length, 1
			first_posted = ActiveSupport::JSON.decode($POSTED_DATA.first['data'])
			assert_equal first_posted['requests'].size, 1
			k = first_posted['requests'].first['activerecord_loads'].keys.first
			assert_equal first_posted['requests'].first['activerecord_loads'][k]['read_attributes'].first, 'value'
			assert_equal first_posted['requests'].first['activerecord_loads'][k]['class'], "PeekerTest::UnkeyedTest"
			assert_match /attribute_peeker.rb/, first_posted['requests'].first['activerecord_loads'][k]['location'].first
		end
		
		should 'recognize used columns through the attributes array' do
		end
		
		should 'recognized used columns through relations' do
		end
	end

end
