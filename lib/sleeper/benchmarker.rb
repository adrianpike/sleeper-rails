module Sleeper
  	module Benchmarker
	  mattr_accessor :enabled, :start_time
	
	  def self.enable!; @@enabled=true; end
	  def self.disable!; @@enabled=false; end

		def self.prepare_request(env = {})
			@@start_time = Time.current.to_f
		end
	
		def self.finish_request(env = {})
			if env["action_controller.rescue.response"]
				controller = env["action_controller.rescue.response"].instance_variable_get('@template').instance_variable_get('@controller')
				db_sum = controller.instance_variable_get('@db_rt_before_render') + controller.instance_variable_get('@db_rt_after_render') rescue nil
				view_time = controller.instance_variable_get('@view_runtime')
			else
				@@stop_time = Time.current.to_f
				view_time = (@@stop_time - @@start_time) * 1000
				db_sum = nil
			end
			
			Sleeper.statistics.add_to_this_request({'view_time'=>view_time,'database_time'=>db_sum})
		end

	end	
end