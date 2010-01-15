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

class ExplainerTest < Test::Unit::TestCase

	class UnkeyedTest < ActiveRecord::Base;	end
	class KeyedTest < ActiveRecord::Base;	end

	context 'with explainer turned on' do
		setup do
			Sleeper.init({
				:sleeper_host=>'http://localhost',
				:log=>STDOUT,
				:client_key=>'foobar',
	        	:debug => true,
	        	:benchmarking => false,
	        	:explaining => true,
	        	:traces => false,
	        	:profiling => false,
	        	:peeking => false,
						:max_update_size => 10000 # 10k
	      	}
			)
		end
		
		context 'an ActiveRecord store' do
			setup do
				
			end
		
			context 'backed by MySQL' do
				setup do 
					mysql_connection = {
					    :adapter  => "mysql",
					    :host     => "localhost",
					    :username => "sleeper_test",
					    :password => "sleeper_test",
					    :database => "sleeper_test"
					}
					
					UnkeyedTest.establish_connection(mysql_connection)
					KeyedTest.establish_connection(mysql_connection)
				end
		
				should 'explain an explainable query' do
					env = {
						'REQUEST_URI' => 'testing'
					}
					Sleeper.prepare_request(env)
					
					uk=UnkeyedTest.find_all_by_key('foobar')

					$POSTED_DATA = []
					
					Sleeper.finish_request(env)
					Sleeper.statistics.gather_host_data
					Sleeper.statistics.upload!
					
					assert_equal $POSTED_DATA.length, 1
					first_request = ActiveSupport::JSON.decode($POSTED_DATA.first['data'])['requests'].first
					
					assert_equal first_request['explained'].length, 1
					
					assert_not_nil first_request['explained'].first['query']
					assert_not_nil first_request['explained'].first['explanation']
					assert_match /ConnectionAdapters::Mysql/, first_request['explained'].first['connection_adapter']
					assert_equal first_request['explained'].first['explanation']['select_type'], 'SIMPLE'
				end

				should 'explain or log everything it can on full CRUD lifecycle' do
					$POSTED_DATA = []
					env = {
						'REQUEST_URI' => 'testing'
					}
					
					Sleeper.prepare_request(env)
					
					UnkeyedTest.delete_all
					UnkeyedTest.create({
						:key => 'lol',
						:value => 'testing'
					})
					
					t=UnkeyedTest.find_by_key('lol')
					t.value = 'hahaha'
					t.save
					
					v=UnkeyedTest.find_by_key('lol')
					assert_equal 'hahaha', v.value
					v.destroy
					
					Sleeper.finish_request(env)
					Sleeper.statistics.gather_host_data
					Sleeper.statistics.upload!
					
					assert_equal $POSTED_DATA.length, 1
					first_request = ActiveSupport::JSON.decode($POSTED_DATA.first['data'])['requests'].first
					assert_equal 4, first_request['unexplained'].size
					assert_equal 2, first_request['explained'].length
				end

				should 'not explain selects outside of requests' do
				end
			end
		
			should 'explain Postgres' do
			end
		
			should 'not explain sqlite' do
			end
			
		end
		
		context 'a DataMapper store' do
		end

	end

end