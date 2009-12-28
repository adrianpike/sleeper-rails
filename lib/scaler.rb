begin
	require 'ruby-prof'
rescue MissingSourceFile
	begin
		require 'profiler'
	rescue MissingSourceFile
	end
end


module Scaler
	VERSION = '0.3'
	
	mattr_accessor :logger

	def self.init(manual_config=nil)
		ENV['SLEEPER-VERSION'] = VERSION
		
		log_path = RAILS_ROOT + '/log/sleeper.log' unless manual_config
		log_path = manual_config[:log] if manual_config
		
		 ENV['SLEEPER-LOG'] = log_path.to_s
		
		@logger = Logger.new(log_path)
		
		if in_webapp? then
			log { "Loading..." }

			@config = Configurator.new(manual_config)
			@statistics = Statistics.new
		
			load_modules
		
			log { 'Loaded, we\'re running.' }
		else
			log { 'Not in a recognized framework, Sleeper is disabled.' }
			log { Module.constants.to_json } if ENV['SLEEPER_DEBUG']=='true'
			log { ENV.to_hash.to_json } if ENV['SLEEPER_DEBUG']=='true'
		end
	end
	
	def self.sanitize_callback(callback)
		callback.collect {|line|
			(line.match(/\/activesupport/) or line.match(/\/activerecord/) or line.match(/\/actionpack/) or line.match(/\/sleeper-rails/)) ? nil : line
		}.compact
	end
		
	# this is all really nasty because there's no uninclude yet
	# basically if you enable something and then disable it, it's still there hogging up some memory until you restart your passenger or mongrel.
	def self.unload_modules
		log { 'Disabling benchmarker...' }
		Benchmarker.disable!

		log { 'Disabling explainer...' }
		Explainer.disable!
		
		log { 'Disabling profiler...' }
		Profiler.disable!
	end

	def self.load_modules
		if config?(:benchmarking) then 
			log { "Initializing benchmarker..." }
			ActionController::Base.class_eval { include Benchmarker } unless ActionController::Base.include?(Benchmarker)
			Benchmarker.enable!
		end

		if config?(:explaining) and Rails.env!='cucumber' then
			log { "Initializing explainer..." }
			ActiveRecord::Base.class_eval { include Explainer } unless ActiveRecord::Base.include?(Explainer)
			Explainer.enable!
		end

		if config?(:profiling) then
			if defined?(RubyProf) or defined?(Profiler__) then
				log { "No RubyProf, we'll be using the builtin ruby Profiler, THINGS WILL BE SLOW!" } unless defined? Rubyprof
				log { "Initializing profiler..." }
				ActionController::Base.class_eval { include Profiler } unless ActionController::Base.include?(Profiler)
				Profiler.enable!
			else
				log { "Can't initialize profiler, try: gem install ruby-prof" }
			end
		end

		if config?(:peeking) then
			log { "Initializing attribute peeker..." }
			ActiveRecord::Base.class_eval { include AttributePeeker } unless ActiveRecord::Base.include?(AttributePeeker)
			AttributePeeker.enable!
		end
	end

	def self.config?(value)
		@config.config(value)
	end

	def self.statistics; @statistics; end

	def self.log(category = :scaler, level=Logger::INFO)
		@logger && @logger.add(level) { "[#{category.to_s.upcase} #{Time.now.to_s :db}] #{yield}" }
	end

	def self.in_webapp?
		if defined? Mongrel::HttpServer
			log { 'Mongrel-backed environment booting, initializing Sleeper...' }
			return true 
		end
		
		if defined? Passenger or defined? PhusionPassenger
			log { 'Passenger-backed environment booting, initializing Sleeper...' }
			return true 
		end
		
		if ENV['HEROKU_ENV'] or ENV['HEROKU_SLUG'] # Theoretically should get picked up by the Thin finder, but we'll probably want to do extra magic for Heroku.
			log { 'Heroku-backed environment booting, initializing Sleeper...' }
			return true
		end
		
	  if defined? FCGI
			log { 'FastCGI-backed environment booting, initializing Sleeper...' }
			return true
		end
		
		# WEBrick needs to be checked before Thin
		if defined? WEBrick::VERSION
			log { 'WEBrick-backed environment booting, initializing Sleeper...' }
			return true 
		end

		if defined? Thin::Server
			log { 'Thin-backed environment booting, initializing Sleeper...' }
			return true
		end
		if defined? Unicorn::HttpServer
			log { 'Unicorn-backed environment booting, initializing Sleeper...' }
			return true
		end

		return true if ENV['FAKE_WEBAPP'] # For testing :)

		false
	end

end