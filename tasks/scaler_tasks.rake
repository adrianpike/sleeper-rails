# desc "Explaining what the task does"
# task :scaler do
#   # Task goes here
# end


namespace(:sleeper) do
	
	desc('Walk around a site, push buttons, pull levers, and generally try to wreak havoc.')
	task :walk => :environment do |t,args|
		@w = Scaler::Walker.new(args.host,true)
		@w.walk!(args.depth || 10)
	end
	
	desc('Notify sleeper that we\'ve just deployed.')
	task :deploy do
		
	end
	
	desc('Install and configure a basic Sleeper installation.')
	task :install do
		
		@config = {}
		
		printf <<-EOM
====================================
  _____ _                           
 / ____| |                          
| (___ | | ___  ___ _ __   ___ _ __ 
 \\___ \\| |/ _ \\/ _ \\ '_ \\ / _ \\ '__|
 ____) | |  __/  __/ |_) |  __/ |   
|_____/|_|\\___|\\___| .__/ \\___|_|   
                   | |              
                   |_|
====================================
Welcome to sleeper! Let's get you up and running as quickly as possible!\n
EOM

	if (File.exists?(RAILS_ROOT+'/config/sleeper.yml')) then
		printf "Sleeper is already configured.\n"
	else

		@config[:client_key] = get_key
	
		printf "Now let's ask a couple of quick questions on how you want sleeper to work when it cannot configure itself from the site.\n"
	
		printf "How many seconds do you want between uploading data to the central sleeper server? [60]"
		val = STDIN.gets.chomp.to_i
		@config[:update_time] = val > 0 ? val : 60

		printf "How many seconds do you want between updates of the sleeper configuration? [600]"
		val = STDIN.gets.chomp.to_i
		@config[:config_update_time] = val > 0 ? val : 600

		printf "Do you want to enable debug mode? [n]"
		val = STDIN.gets.chomp.match(/y(es)?/i)
		@config[:debug] = val ? true : false
	
		@file = File.new(RAILS_ROOT+'/config/sleeper.yml','w+')
		@file.write(@config.to_yaml)
		@file.close
	
		printf "\nExcellent, Sleeper is configured and ready to go!\n"	
	end
	end
	
	
	def get_key
		printf "What's your sleeper key? "
		key = STDIN.gets.chomp
		printf "\nYou entered '#{key}', is this correct? (y/n)"
		 return key if (STDIN.gets.match(/^y$/i))
		get_key	
	end
end