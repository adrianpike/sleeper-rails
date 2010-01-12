module Sleeper
	class Middleware
		def initialize(app)
			# This happpens before every request.
			@app = app
		end

		def call(env); dup._call(env); end # To make it thread-safe

		def _call(env)
			# Do any preparation we need for the app call
			
			@status, @headers, @response = @app.call(env)
			
			Sleeper.log { 'Just finished a request.' }
			Sleeper.statistics.finish_request!(env)
			# Do any cleanup we need here
		
			[@status, @headers, @response]
		end
	end
end