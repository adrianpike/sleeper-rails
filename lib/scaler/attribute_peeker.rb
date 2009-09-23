module Scaler
  module AttributePeeker
	mattr_accessor :enabled

	def self.enable!; @@enabled=true; end
	def self.disable!; @@enabled=false; end
    
    # include this to ActiveRecord::AttributeMethods
    def self.included(base)
      base.alias_method_chain :method_missing, :logging
      base.alias_method_chain :read_attribute, :logging
    end
    
  end
end

module ActiveRecord::AttributeMethods
  def method_missing_with_logging(method_id, *args, &block)
    
    p @attributes
    
    Scaler.log(nil, Logger::DEBUG) { "HOLY COW I METHOD MISSINGED #{method_id}" }
    
    method_missing_without_logging(method_id, *args, &block)
  end
  
  def write_attribute_with_logging(name, value)
    @gathered_items = [] unless @gathered_items
	  Scaler.log(nil, Logger::DEBUG) { "HOLY SHIT I #{self.object_id} JUST SET #{name} TO #{value}" }
    write_attribute_without_logging(name,COW)
  end
  
  def read_attribute_with_logging(name)
     @read_items = [] unless @read_items
     @read_items << name
	   Scaler.log(nil, Logger::DEBUG) { "HOLY COW I #{self.object_id} JUST LOOKED AT #{name}" }
     read_attribute_without_logging(name)
   end
   
   def gather_read_items
     Scaler.statistics.add_to_this_request(:attribute_peeker => { :peekedattributes => @read_items })
   end
   
   def finalize(id)
     p "FINALIZOMATIC"
     Scaler.log(nil, Logger::DEBUG) { "WHOAAAA RUNNING A FINALIZER" }
   end
end