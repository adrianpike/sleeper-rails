require 'test_helper'

class ExplainerTest < Test::Unit::TestCase

	context 'with explainer turned on' do
		
		context 'an ActiveRecord store' do
		
			should 'explain MySQL' do
			end
		
			should 'include unexplained queries with the data package' do
			end
		
			should 'explain Postgres' do
			end
		
			should 'not explain sqlite' do
			end
			
		end
		
		context 'a DataMapper store' do
		end

	end

end