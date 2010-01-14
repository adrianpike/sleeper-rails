module Sleeper
  	module Benchmarker
	  mattr_accessor :enabled, :start_time
	
	  def self.enable!; @@enabled=true; end
	  def self.disable!; @@enabled=false; end

		def self.prepare_request
			@@start_time = Time.current.to_f unless defined? Rails
		end
	
		def self.finish_request(env)
			if defined? Rails
				template = env["action_controller.rescue.response"].template
				db_sum = template.instance_variable_get('@db_rt_before_render') + template.instance_variable_get('@db_rt_after_render') rescue nil
				view_time = template.instance_variable_get('@view_runtime')
			else
				@@stop_time = Time.current.to_f
				view_time = (@@stop_time - @@start_time) * 1000
				db_sum = nil
			end
			
			Sleeper.statistics.add_to_this_request({'view_time'=>view_time,'database_time'=>db_sum})
		end

		# DEPRECATED
		
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