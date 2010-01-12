require 'net/http'
require 'uri'

begin
  require 'sys/cpu'
rescue MissingSourceFile
end

module Sleeper
  class Statistics    
    def initialize
	    @data = empty_data_set
      @request = {}
      @running = true
	    @in_child = false
	  
	    unless $0 =~ /ApplicationSpawner/ then
	      @thread = fire_upload_thread!
				ENV['SLEEPER-UPLOAD-THREAD'] = @thread.inspect
	      @thread.abort_on_exception=true
      end
    end
  
    def empty_data_set; { :requests => [] }; end
  
	  def fire_upload_thread!
	    Thread.new { upload_thread }
    end

	  ## Stuff that gets called by the main Rails thread
    def add_to_this_request(info={}); @request.merge!(info); end

		def request_key(key)
			@request[key]
		end
		
		def set_request_key(key,val)
			@request[key] = val
		end

    def append_to_this_request_key(key,value)
      @request[key] << value if @request[key]
      @request[key] = [value] unless @request[key]
    end
    
    def finish_request!(env)
	 		@request[:time] = Time.new
      @request[:url] = env['REQUEST_URI']
      #["action_controller.rescue.request", "SERVER_NAME", "PATH_INFO", "rack.url_scheme", "rack.run_once", "rack.input", "action_controller.request.request_parameters", "SCRIPT_NAME", "SERVER_PROTOCOL", "HTTP_HOST", "rack.errors", "REMOTE_ADDR", "SERVER_SOFTWARE", "REQUEST_PATH", "rack.request.query_hash", "HTTP_VERSION", "rack.multithread", "rack.version", "action_controller.request.path_parameters", "REQUEST_URI", "rack.multiprocess", "SERVER_PORT", "rack.request.query_string", "action_controller.rescue.response", "rack.session.options", "GATEWAY_INTERFACE", "QUERY_STRING", "action_controller.request.query_parameters", "rack.session", "HTTP_ACCEPT", "REQUEST_METHOD"]

      @data[:requests] << @request
      @request = {}
    end

    def gather_host_data
      @data[:load_average] = Sleeper::HostStats.load_average
      @data[:free_memory] = Sleeper::HostStats.free_memory
			@data[:version] = Sleeper::VERSION
    end
    
	# Thread-related goodies
    def upload_thread
      while @running
        sleep Sleeper.config?(:update_time).to_i
     
        begin
          Sleeper.log(:statistics) { 'Uploading statistics ('+(@data[:requests].size.to_s rescue 'unknown')+' requests) to '+Sleeper.config?(:sleeper_host)+' with key '+Sleeper.config?(:client_key)+'...' }
          gather_host_data
          upload!
          @data = empty_data_set
        rescue Exception => e
          Sleeper.log(:error, Logger::ERROR) { e }
        end
      end
    end
  
		# hat tip: http://snippets.dzone.com/posts/show/3486
		def chunk_array(array, pieces=2)
		  len = array.length;
		  mid = (len/pieces)
		  chunks = []
		  start = 0
		  1.upto(pieces) do |i|
		    last = start+mid
		    last = last-1 unless len%pieces >= i
		    chunks << array[start..last] || []
		    start = last+1
		  end
		  chunks
		end

		def json_data_chunks
			jsoned = @data.to_json
			if jsoned.size>Sleeper.config?(:max_update_size)
				stub_request = @data.dup
				stub_request.delete(:requests)
				
				stub_size = stub_request.to_json.size + 15 # overhead for key & brackets
				overhead_size = jsoned.size - stub_size
				
				num_chunks = (((jsoned.size.to_f/Sleeper.config?(:max_update_size).to_f).ceil*overhead_size.to_f + stub_size.to_f) / Sleeper.config?(:max_update_size).to_f).ceil
				
				requests = chunk_array(@data[:requests], num_chunks)
				requests.collect {|r| 
					new_req = stub_request.dup
					new_req[:requests] = r
					new_req
				}.collect{|r| r.to_json }
			else
				[jsoned]
			end
		end

    def upload!
			json_data_chunks.each{|data|
				begin
					Timeout::timeout(Sleeper.config?(:upload_timeout)) {
						Sleeper.log(:statistics) { ' - Uploading chunk of ' + data.size.to_s + ' bytes.' }
	      		uri = URI.parse(Sleeper.config?(:sleeper_host)+'/apps/'+Sleeper.config?(:client_key))
	      		res = Net::HTTP.post_form(uri, {'data'=>data})
						case res.code
							when '200'
								Sleeper.log(:statistics) { '[ACCEPTED]' }
							when '401'
								Sleeper.log(:statistics) { '[REJECTED] - Sleeper doesn\'t recognize your key!' }
							when '413'
								Sleeper.log(:statistics) { '[REJECTED] - This was too big a submission to Sleeper.' }
							else
								Sleeper.log(:statistics) { '[REJECTED] - There was a Sleeper server error:'+res.code.to_s }
						end
					}
				rescue Timeout::Error
					Sleeper.log(:sleeper, Logger::ERROR) { 'Timeout contacting the Sleeper server, they probably screwed up.' }
				end
    	}
			Sleeper.log(:statistics) { 'Statistics batch complete.' }
		end
  end
end

if defined?(PhusionPassenger)
    PhusionPassenger.on_event(:starting_worker_process) do |forked|
        Sleeper.statistics.fire_upload_thread! if forked
    end
end