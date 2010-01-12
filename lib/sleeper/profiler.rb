module Sleeper
  module Profiler
	mattr_accessor :enabled, :mode

	def self.enable!; @@enabled=true; end
	def self.disable!; @@enabled=false; end
		    
    def start_profiling
			if @@enabled then
				case @@mode
				when :RubyProf
	      	RubyProf.start rescue RuntimeError
				when :Profiler
					Profiler__.start_profile
				end
			end
    end
    
    def finish_profiling
			if @@enabled then
				
				case @@mode
				when :RubyProf
	     		results = RubyProf.stop
	    		output = String.new
					RubyProf::FlatPrinter.new(results).print(output,0)
     		when :Profiler
					sio = StringIO.new
					Profiler__.stop_profile
					begin
						Profiler__.print_profile(sio)
					rescue TypeError
					end
					
					sio.rewind
					output = sio.read
				end

    		Sleeper.statistics.add_to_this_request({'profiling_mode'=>@@mode,'profiling'=>output})
			end
    end
   
    def self.included(base)
      base.send 'before_filter', 'start_profiling' #TODO
	  	base.send 'after_filter', 'finish_profiling' #TODO

			if defined? Profiler__ then
				@@mode = :Profiler
			end

			if defined? RubyProf then
				@@mode = :RubyProf
				RubyProf.measure_mode = RubyProf::WALL_TIME
			end
			
    end 
  end
end