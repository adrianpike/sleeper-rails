require 'net/http'
require 'uri'

begin
  require 'sys/cpu'
rescue MissingSourceFile
end

module Scaler
  class Statistics    
    def initialize
		Scaler.log { RUBY_VERSION }
	  @data = empty_data_set
      @request = {}
      @running = true
	  @in_child = false
	  @@thread = fire_upload_thread!
	  @@thread.abort_on_exception=true
    end
  
    def empty_data_set; { :requests => [] }; end
  
	def fire_upload_thread!
	  Thread.new { upload_thread }
    end

	## Stuff that gets called by the main Rails thread
    def add_to_this_request(info={}); @request.merge!(info); end
    
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

	  Scaler.log { 'FINISHED REQUEST:' + @data.to_yaml }
    end

    def gather_host_data
      @data[:load_average] = Scaler::HostStats.load_average
      @data[:free_memory] = Scaler::HostStats.free_memory
    end
    
	# Thread-related goodies
    def upload_thread
      while @running
        sleep Scaler.config?(:update_time).to_i
     
        begin
		  Scaler.log { 'UPLOAD THREAD:' + @data.to_yaml }
	
          Scaler.log(:statistics) { 'Uploading statistics ('+(@data[:requests].size.to_s rescue 'unknown')+' requests) to '+Scaler.config?(:sleeper_host)+' with key '+Scaler.config?(:client_key)+'...' }
          gather_host_data
          upload!
          @data = empty_data_set
        rescue Exception => e
          Scaler.log(:error, Logger::ERROR) { e }
        end
      end
    end
  
    def upload!
		begin
			Timeout::timeout(Scaler.config?(:upload_timeout)) {
	      		uri = URI.parse(Scaler.config?(:sleeper_host)+'/apps/'+Scaler.config?(:client_key))
	      		res = Net::HTTP.post_form(uri, {'data'=>@data.to_json})
			}
		rescue Timeout::Error
			Scaler.log(:scaler, Logger::ERROR) { 'Timeout contacting the Sleeper server, they probably screwed up.' }
		end
    end
  end
end