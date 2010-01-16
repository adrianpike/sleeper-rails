SLEEPER_DONT_BOOT = true; require(File.dirname(__FILE__) + "/../../../../config/environment") unless defined?(Rails)

require 'test_helper'

class ExplainerTest < Test::Unit::TestCase

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
					prepare_sleeper_test!
					
					uk=UnkeyedTest.find_all_by_key('foobar')

					finish_sleeper_test!

					assert_equal $POSTED_DATA.length, 1
					first_request = ActiveSupport::JSON.decode($POSTED_DATA.first['data'])['requests'].first
					
					assert_equal first_request['explained'].length, 1
					
					assert_not_nil first_request['explained'].first['query']
					assert_not_nil first_request['explained'].first['explanation']
					assert_match /ConnectionAdapters::Mysql/, first_request['explained'].first['connection_adapter']
					assert_equal first_request['explained'].first['explanation']['select_type'], 'SIMPLE'
				end

				should 'explain or log everything it can on full CRUD lifecycle' do
					prepare_sleeper_test!
					
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
					
					finish_sleeper_test!
		
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