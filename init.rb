unless defined? SLEEPER_DONT_BOOT
	$:.unshift "#{File.dirname(__FILE__)}/lib"
	Sleeper.init
end