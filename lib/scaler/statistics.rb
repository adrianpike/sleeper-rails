require 'net/http'
require 'uri'

begin
  require 'sys/cpu'
rescue MissingSourceFile
end

module Scaler
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
    
    def finish_request!(controller)
      controller.finish_profiling if controller.respond_to? :finish_profiling
      
      @request[:time] = Time.new
      @request[:url] = controller.request.request_uri
      @request[:action] = controller.action_name
      @request[:controller] = controller.controller_name
      
      if Scaler.config?(:verbose_statistics) then
        @request[:ssl] = controller.ssl?
        @request[:port] = controller.request.port
        @request[:remote_addr] = controller.remote_addr
      end
      
      @data[:requests] << @request
      @request = {}
    end

    def gather_host_data
      @data[:load_average] = Scaler::HostStats.load_average
      @data[:free_memory] = Scaler::HostStats.free_memory
			@data[:version] = Scaler::VERSION
    end
    
	# Thread-related goodies
    def upload_thread
      while @running
        sleep Scaler.config?(:update_time).to_i
     
        begin
          Scaler.log(:statistics) { 'Uploading statistics ('+(@data[:requests].size.to_s rescue 'unknown')+' requests) to '+Scaler.config?(:sleeper_host)+' with key '+Scaler.config?(:client_key)+'...' }
          gather_host_data
          upload!
          @data = empty_data_set
        rescue Exception => e
          Scaler.log(:error, Logger::ERROR) { e }
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
			if jsoned.size>Scaler.config?(:max_update_size)
				stub_request = @data.dup
				stub_request.delete(:requests)
				
				stub_size = stub_request.to_json.size + 15 # overhead for key & brackets
				overhead_size = jsoned.size - stub_size
				
				num_chunks = (((jsoned.size.to_f/Scaler.config?(:max_update_size).to_f).ceil*overhead_size.to_f + stub_size.to_f) / Scaler.config?(:max_update_size).to_f).ceil
				
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
					Timeout::timeout(Scaler.config?(:upload_timeout)) {
						Scaler.log(:statistics) { ' - Uploading chunk of ' + data.size.to_s + ' bytes.' }
	      		uri = URI.parse(Scaler.config?(:sleeper_host)+'/apps/'+Scaler.config?(:client_key))
	      		res = Net::HTTP.post_form(uri, {'data'=>data})
						case res.code
							when '200'
								Scaler.log(:statistics) { '[ACCEPTED]' }
							when '401'
								Scaler.log(:statistics) { '[REJECTED] - Sleeper doesn\'t recognize your key!' }
							when '413'
								Scaler.log(:statistics) { '[REJECTED] - This was too big a submission to Sleeper.' }
							else
								Scaler.log(:statistics) { '[REJECTED] - There was a Sleeper server error:'+res.code.to_s }
						end
					}
				rescue Timeout::Error
					Scaler.log(:scaler, Logger::ERROR) { 'Timeout contacting the Sleeper server, they probably screwed up.' }
				end
    	}
			Scaler.log(:statistics) { 'Statistics batch complete.' }
		end
  end
end

if defined?(PhusionPassenger)
    PhusionPassenger.on_event(:starting_worker_process) do |forked|
        if forked
            # We're in smart spawning mode.
            Scaler.statistics.fire_upload_thread!
        else
            # We're in conservative spawning mode. We don't need to do anything.
        end
    end
end