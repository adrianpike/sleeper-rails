require 'test_helper'
require 'rack/lobster'

$POSTED_DATA = []

module Net
	class HTTP
		def self.post_form(url, content)
			$POSTED_DATA << content

			Net::HTTPResponse.new("fake_http","200",'hooray!')
		end
	end
end

class BenchmarkerTest < Test::Unit::TestCase
	context 'with benchmarking turned on' do
		setup do
			Sleeper.init({
				:sleeper_host=>'http://localhost',
				:log=>STDOUT,
				:client_key=>'foobar',
	        	:debug => true,
	        	:benchmarking => true,
	        	:explaining => false,
	        	:traces => false,
	        	:profiling => false,
	        	:peeking => false,
						:max_update_size => 10000 # 10k
	      	}
			)
		end
		
		should 'benchmark a pure rack request' do
			test_url = '/fooo/dasfasd'
			browser = Rack::Test::Session.new(Rack::MockSession.new(
			Rack::Builder.new {
	 			map "/" do
					use Rack::Head
	 				use Sleeper::Middleware
					run Rack::Lobster.new
	 			end
	 		}.to_app
			))
			
			st_time = Time.current.to_f
			browser.get(test_url)
			time = (Time.current.to_f - st_time) * 1000
			
			Sleeper.statistics.gather_host_data
			Sleeper.statistics.upload!
			
			assert_equal $POSTED_DATA.length, 1
			first_posted = ActiveSupport::JSON.decode($POSTED_DATA.first['data'])
			assert_equal first_posted['requests'].size, 1
			assert_equal first_posted['requests'].first['url'], test_url
			assert_not_nil first_posted['requests'].first['view_time']
			assert_in_delta first_posted['requests'].first['view_time'], time, 20
		end
		
		should 'benchmark a rails request' do
			test_url = '/fooo/dasfasd'
			
			browser = Rack::Test::Session.new(Rack::MockSession.new(
			Rack::Builder.new {
	 			map "/" do
					use Rack::Head
	 				use Sleeper::Middleware
					run ActionController::Dispatcher.new
	 			end
	 		}.to_app
			))
			
			browser.get test_url
			
		end
	end

end