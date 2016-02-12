require 'rubygems'
require 'daemons'
options= {:backtrace => true, :monitor => true}
Daemons.run('main_scenario.rb',options)