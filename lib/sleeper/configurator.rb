module Sleeper
  class Configurator

    # Most of this will be overwritten by config_thread
    def default_configuration
      {
        :client_key => nil,
        :client_secret => nil,
        :sleeper_host => 'http://sleeperapp.com',
        :update_time => 60, # in seconds
        :config_update_time => 600, # every ten minutes
        :debug => false,
        :benchmarking => true,
        :explaining => true,
        :traces => false,
				:trace_depth => 10,
				:max_update_size => 2000000, # in bytes. ~2MB
        :profiling => false,
        :peeking => false,
				:upload_timeout => 60, # Could take a while to stuff 2MB upstream ;)
				:compression => true, # TODO
				:verbose_statistics => false # TODO
      }
    end
    
    def initialize(manual_config=nil)
      @running = true
      
	 		if manual_config
		  	@config = default_configuration.merge(manual_config)
      else
				@config = default_configuration
				output = ERB.new(File.open("#{RAILS_ROOT}/config/sleeper.yml").read).result
				@config.merge!(YAML::load(output)) rescue nil

     		ENV['SLEEPER-CONFIG-THREAD'] = Thread.new { 
            	sleep 5 # initial time before we rock and roll
            	config_thread
          	}.inspect
				
				end
    end
    
    def update_config
      uri = URI.parse(@config[:sleeper_host]+'/apps/'+@config[:client_key]+'/environments/'+Rails.env+'.js')
      result = Net::HTTP.get(uri) rescue nil
      new_config = Hash[*ActiveSupport::JSON.decode(result).collect{|k,v| {k.to_sym=>v} }.collect{|z| z.to_a }.flatten]
      @config.merge!(new_config) rescue nil
      # TODO: re analyze config, uninstall everything and reinstall what needs to be reinstalled

	  # there's a few second hole here where modules will flicker off & on
	  Sleeper.unload_modules
	  Sleeper.load_modules
    end
    
    def config_thread
      while @running
        begin
          Sleeper.log(:config) { 'Updating configuration...' }
          update_config
		rescue ActiveSupport::JSON::ParseError
			Sleeper.log(:config) { 'Unable to update configuration, we received some bad JSON. (Is Sleeper down?) We\'ll try again in a few minutes.' }
			sleep 600 # wait 10 minutes, we'll use default behavior for now
        rescue Exception => e
          Sleeper.log(:error, Logger::ERROR) { e }
          Sleeper.log(:error, Logger::ERROR) { e.backtrace.join("\n") }
        end
        sleep Sleeper.config?(:config_update_time)
      end
    end
    
    def config(key);@config[key];end
    
  end
end