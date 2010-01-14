module Sleeper
	class Middleware
		def initialize(app)
			# This happpens before every request.
			@app = app
		end

		def call(env); dup._call(env); end # To make it thread-safe

		def _call(env)
			Sleeper.prepare_request(env)
			
			@status, @headers, @response = @app.call(env)
			
			Sleeper.finish_request(env, @status, @headers, @response)
			
			[@status, @headers, @response]
		end
	end
end