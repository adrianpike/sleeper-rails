### AR object lifecycle:
# columns loaded
# columns read / written
# gc'ed

module Scaler
  module AttributePeeker
	mattr_accessor :enabled

	def self.enable!; @@enabled=true; end
	def self.disable!; @@enabled=false; end
    
    # include this to ActiveRecord::AttributeMethods
    def self.included(base)
      Scaler.log(:peeker, Logger::DEBUG) { "EXTENDING AR::Base" }
			
			#base.alias_method_chain :define_attribute_methods, :logging
			ActiveRecord::AttributeMethods::ClassMethods.alias_method_chain :define_read_method, :logging
			
			#ActiveRecord::AttributeMethods.class_eval { alias_method_chain :method_missing, :logging }
			
      #base.alias_method_chain :read_attribute, :logging
			
    end
    
  end
end

module ActiveRecord::AttributeMethods
	module ClassMethods
		def define_read_method_with_logging(symbol, attr_name, column)
		  Scaler.log(:peeker, Logger::DEBUG) { "HOLY COW I #{self.object_id} JUST DEFINED A READ METHOD FOR #{symbol}" }

			define_read_method_without_logging(symbol, attr_name, column)
			
			logging_code = "def #{attr_name}_with_logging; p 'SKEET SKEET SKEET SKEET'; end"
			chain_code = "alias_method_chain :#{attr_name},:logging"
			
			class_eval(logging_code)
			class_eval(chain_code)
	 end

	end
  
  def read_attribute_with_logging(name)
     @read_items = [] unless @read_items
     @read_items << name
	   Scaler.log(:peeker, Logger::DEBUG) { "HOLY COW I #{self.object_id} JUST LOOKED AT #{name}" }
     define_attribute_methods_without_logging(name)
   end

   def gather_read_items
     Scaler.statistics.add_to_this_request(:attribute_peeker => { :peekedattributes => @read_items })
   end
   
   def finalize(id)
     p "FINALIZOMATIC"
     Scaler.log(:peeker, Logger::DEBUG) { "WHOAAAA RUNNING A FINALIZER" }
   end
end