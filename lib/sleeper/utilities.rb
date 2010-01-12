module Sleeper
	class Utilities
		
		def self.sanitize_callback(callback)
			callback.collect {|line|
				(line.match(/\/activesupport/) or line.match(/\/activerecord/) or line.match(/\/actionpack/) or line.match(/\/sleeper-rails/) or line.match(/\/rack/)) ? nil : line
			}.compact
		end
	
	end
end