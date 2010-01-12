require 'test_helper'
require 'shoulda'

ENV['FAKE_WEBAPP'] = '1'

class PostedSomeStuff < Exception; end

$POSTED_DATA = []

module Net
	class HTTP
		def self.post_form(url, content)
			$POSTED_DATA << content
			
			
			Net::HTTPResponse.new("fake_http","200",'hooray!')
		end
	end
end

class SleeperTest < Test::Unit::TestCase

	context 'sleeper configured to pull things off the internet' do
		should 'pull down a config' do
		end
	end

	context 'sleeper config a manual configuration of everything off' do
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
	        	:peeking => false,
						:max_update_size => 500
	      	}
			)
			
			@request = stub({:request_uri=>'test'})
			@controller = stub({
				:request=>@request,
				:action_name=>'test_action',
				:controller_name=>'test_controller_name',
				'ssl?'=>false,
				:port=>'interwebs_port',
				:remote_addr=>'bigtruck.com'
			})
		end
			
		should 'post some basic data and have sane results' do
			Sleeper.statistics.add_to_this_request({:foo=>'bar'})
			Sleeper.statistics.finish_request!(@controller)
			Sleeper.statistics.gather_host_data
			
			$POSTED_DATA = []
			
			Sleeper.statistics.upload!
				
			results = ActiveSupport::JSON.decode($POSTED_DATA.last['data'])
			
			# has sane load averages
			assert results['load_average'].match(/^(\d+.\d+\w?)+/)
			
			# has all the awesome info about locations & actions & what-not
			assert results['requests'].size==1
			assert results['requests'].first['action']=='test_action'
			assert results['requests'].first['url']=='test'
			assert results['requests'].first['foo']=='bar'
			assert results['requests'].first['controller']=='test_controller_name'
			
			# has sane some free_memory infos
			assert results['free_memory']
		end
		
		should 'chunk up huge posts' do
			10.times do |i|
				Sleeper.statistics.add_to_this_request({:foo=>'bar', :zed=>i.to_s})
				Sleeper.statistics.finish_request!(@controller)
			end
			
			Sleeper.statistics.gather_host_data
			
			$POSTED_DATA = []
			
			Sleeper.statistics.upload!
			
			assert_equal $POSTED_DATA.length, 9
			
			first_posted = ActiveSupport::JSON.decode($POSTED_DATA.first['data'])
			last_posted = ActiveSupport::JSON.decode($POSTED_DATA.last['data'])
			
			
			assert first_posted['load_average'].match(/^(\d+.\d+\w?)+/)
			
			# first and last have same host data
			assert_equal first_posted['free_memory'], last_posted['free_memory']
			assert_equal first_posted['load_average'], last_posted['load_average']
			
			# first and last have different zed data
			assert_not_equal first_posted['requests'].first['zed'], last_posted['requests'].first['zed']
		end
		
		should 'gracefully handle timeouts' do
		end
		
		context 'with explainer turned on' do
			should 'explain sql statements' do
			end
		end
		
		context 'with profiler turned on' do
			should 'profile some code that I run' do
			end
		end
		
		context 'with benchmarking turned on' do
			should 'benchmark an actioncontroller request' do
			end
		end
		
		
		teardown do
			
		end
	end

end