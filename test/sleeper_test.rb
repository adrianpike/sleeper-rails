require 'test_helper'

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
						:max_update_size => 10000 # 10k
	      	}
			)
			
			@env = {
				'REQUEST_URI' => 'http://testery.com/test'
			}
		end
			
		should 'post some basic data and have sane results' do
			Sleeper.statistics.add_to_this_request({:foo=>'bar'})
			Sleeper.statistics.finish_request!(@env)
			Sleeper.statistics.gather_host_data
			
			$POSTED_DATA = []
			
			Sleeper.statistics.upload!
				
			results = ActiveSupport::JSON.decode($POSTED_DATA.last['data'])
			
			# has sane load averages
			assert results['load_average'].match(/^(\d+.\d+\w?)+/)
			
			# has all the awesome info about locations & actions & what-not
			assert results['requests'].size==1
			assert results['requests'].first['url']=='http://testery.com/test'
			assert results['requests'].first['foo']=='bar'
			
			# has sane some free_memory infos
			assert results['free_memory']
		end
		
		should 'chunk up huge posts' do
			bigstr = (0...1000).map{65.+(rand(25)).chr}.join # 1000 bytes
			
			10.times do |i|
				Sleeper.statistics.add_to_this_request({:zed=>i.to_s, :data=>bigstr})
				Sleeper.statistics.finish_request!(@env)
			end
			
			Sleeper.statistics.gather_host_data
			
			$POSTED_DATA = []
			
			Sleeper.statistics.upload!
			
			assert_equal $POSTED_DATA.length, (((bigstr.size+100)*10)/10000.0).ceil+1
			
			first_posted = ActiveSupport::JSON.decode($POSTED_DATA.first['data'])
			last_posted = ActiveSupport::JSON.decode($POSTED_DATA.last['data'])
			
			assert first_posted['load_average'].match(/^(\d+.\d+\w?)+/)
			
			# first and last have same host data
			assert_equal first_posted['free_memory'], last_posted['free_memory']
			assert_equal first_posted['load_average'], last_posted['load_average']
			
			# first and last have different zed data
			assert_not_equal first_posted['requests'].first['zed'], last_posted['requests'].first['zed']
		end
		
		should 'reject horked keys' do
		end
		
		should 'reject gigantor updates' do
		end
		
		should 'handle wacky server errors' do
		end
		
		should 'gracefully handle timeouts' do
		end
				
		should 'be configurable' do
		end
				
		teardown do
			
		end
	end

end