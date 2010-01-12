module Sleeper
  	module Benchmarker
	  mattr_accessor :enabled
	
	  def self.enable!; @@enabled=true; end
	  def self.disable!; @@enabled=false; end
	
      def benchmark_action
				if @@enabled then
	        db_sum = @db_rt_before_render+@db_rt_after_render rescue nil #TODO
	        Sleeper.statistics.add_to_this_request({'view_time'=>@view_runtime,'database_time'=>db_sum})
				end
      end
    
      def self.included(base)
        base.send 'after_filter', 'benchmark_action'
      end
    
	end	
end