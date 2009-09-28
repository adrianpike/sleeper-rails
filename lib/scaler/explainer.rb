require 'benchmark'

module Scaler
	module Explainer
		mattr_accessor :enabled

		def self.enabled?; @@enabled==true; end
		def self.enable!; @@enabled=true; end
		def self.disable!; @@enabled=false; end

		def self.included(base)
			base.extend(ClassMethods)
			base.explain
		end

		class ConnectionWrapper
			def initialize(connection)
				@original_connection = connection
				@explainer = ExplainerDelegate.new(connection)
			end

			delegate :delete, :select, :select_all, :find, :to => :explainer_delegate

			# any data loader methods get dumped into here
			class ExplainerDelegate
				def initialize(connection)
					@connection = connection
				end

				def explain_string(str); "EXPLAIN #{str}";	end

				def method_missing(method, *args, &block)
					Scaler.log(:explainer, Logger::DEBUG) { "#{method} -- #{args.join(":")}" }

					## Explain this shit
					begin
						result = @connection.execute explain_string(args[0])
						explanation = ''
						explanation = result.fetch_hash if result.is_a? Mysql::Result rescue nil
						explanation = result if result.is_a? Array
						Scaler.statistics.append_to_this_request_key(:explained, 
						{
							:query => args[0],
							:connection_adapter=> @connection.class.to_s, 
							:explanation => explanation#,
							#						  :trace => (Scaler.config?(:traces) ? caller : '')
							})
						result.free if result.is_a? Mysql::Result rescue nil
					rescue ActiveRecord::StatementInvalid => e
						Scaler.log(:explainer, Logger::ERROR) { "MySQL Error in explainer: #{e}" }
					end

					@connection.send(method, *args, &block)
				end
			end
			
			def explainer_delegate; @explainer; end

			def respond_to_with_original?(method)
				respond_to_without_original?(method) || @original_connection.respond_to?(method)
			end
			alias_method_chain :respond_to?, :original

			def method_missing(method, *args, &block)
				Scaler.statistics.append_to_this_request_key(:unexplained, { query => args[0] })
				@original_connection.send(method, *args, &block)
			end

		end

		module ClassMethods # To get injected into ActiveRecord::Base
			def explain(options={})
				class << self
					def connection_with_wrapper
						if Scaler::Explainer.enabled? then
							if Rails.configuration.cache_classes
								@@wrapper
							else
								Scaler::Explainer::ConnectionWrapper.new(connection_without_wrapper)
							end
						else
							connection_without_wrapper
						end
					end
					alias_method_chain :connection, :wrapper unless self.respond_to?('connection_without_wrapper')
				end
					@@wrapper = Scaler::Explainer::ConnectionWrapper.new(connection_without_wrapper) if Rails.configuration.cache_classes
			end
		end
	end
end