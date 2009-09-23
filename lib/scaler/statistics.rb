require 'net/http'
require 'uri'

begin
  require 'sys/cpu'
rescue MissingSourceFile
end

module Scaler
  class Statistics
    VERBOSE_REQUESTS = false
    
    def initialize
      @data = empty_data_set
      @request = {}
      @running = true
      
      fire_upload_thread!
    end
  
    def empty_data_set
      {
        :requests => []
      }
    end
  
    def add_to_this_request(info={})
      @request.merge!(info)
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
      
      if VERBOSE_REQUESTS then
        @request[:ssl] = controller.ssl?
        @request[:port] = controller.request.port
        @request[:remote_addr] = controller.remote_addr
      end
      
      @data[:requests] << @request
      @request = {}
    end
    
    def fire_upload_thread!
      Thread.new { 
        sleep 5 # initial time before we rock and roll
        upload_thread 
      }.abort_on_exception=true
    end
    
    def free_memory
      if @linux then
        
      elsif @mac then
        @res = {}
        @meminfo = %x[vm_stat]
        @meminfo.split("\n").each{|item|
         @res[item.split(':').first.strip] = item.split(':').last.strip
        }
        @pagesize = @res['Mach Virtual Memory Statistics'].match(/of ([0-9]+) bytes/)[1]
        (@res['Pages free'].to_i * @pagesize.to_i)
      end
    end
    
    def gather_host_data
      @data[:load_average] = Scaler::HostStats.load_average
      @data[:free_memory] = Scaler::HostStats.free_memory
    end
    
    def upload_thread
      while @running
        sleep Scaler.config?(:update_time).to_i
     
        begin
          Scaler.log { '[STATISTICS] Uploading statistics to '+Scaler.config?(:sleeper_host)+' with key '+Scaler.config?(:client_key)+'...' }
          gather_host_data
          upload!
          @data = empty_data_set
        rescue Exception => e
          Scaler.log { e }
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
			Scaler.log { '[SCALER] - Timeout contacting the Sleeper server, they probably screwed up.' }
		end
    end
  end
end