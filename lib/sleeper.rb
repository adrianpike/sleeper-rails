begin
	require 'ruby-prof'
rescue MissingSourceFile
	begin
		require 'profiler'
	rescue MissingSourceFile
	end
end


module Sleeper
	VERSION = '0.4'
	
	mattr_accessor :logger

	def self.init(manual_config=nil)
		ENV['SLEEPER-VERSION'] = VERSION
		
		log_path = RAILS_ROOT + '/log/sleeper.log' unless manual_config
		log_path = manual_config[:log] if manual_config
		ENV['SLEEPER-LOG'] = log_path.to_s
		
		@logger = Logger.new(log_path)
		begin
			@config = Configurator.new(manual_config)
			@statistics = Statistics.new
			load_modules
			load_middleware
		rescue Errno::ENOENT
			log { 'Looks like Sleeper\'s not configured yet, so I\'ll just chill.' }
		end
	end
	
	def self.load_middleware
		log { "Initializing Sleeper Middleware..." }
		ActionController::Dispatcher.middleware.use(Sleeper::Middleware)
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

	def self.config?(value); @config.config(value);end
	def self.statistics; @statistics; end

	def self.log(category = :sleeper, level=Logger::INFO)
		@logger && @logger.add(level) { "[#{category.to_s.upcase} #{Time.now.to_s :db}] #{yield}" }
	end

end