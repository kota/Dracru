$: << File.dirname(__FILE__)
require 'lib/dracru'

dracru = Dracru.new
dracru.raid_if_possible
