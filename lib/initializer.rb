# -*- coding: utf-8 -*-
require 'rubygems'
require 'logger'
require 'active_record'
require 'sqlite3'
require 'mechanize'
require 'yaml'
require 'lib/core'
require 'lib/dracru'
require 'lib/game_map'

ROOT_PATH = File.expand_path(File.join(File.dirname(__FILE__), '..')) 
TMP_PATH = ROOT_PATH + '/tmp'
if !File.exist?(TMP_PATH) 
  Dir::mkdir TMP_PATH
end
if File::ftype(TMP_PATH) != "directory"
  puts "tmp is not directory. terminate."
  exit
end

$logger = Logger.new(TMP_PATH + '/dracru.log')
$logger.info "---" + Time.now.strftime("%m/%d %H:%M")
COOKIES = TMP_PATH + '/cookies'
DB = TMP_PATH + '/dracru.db'
# ActiveRecord::Base.logger = Logger.new(ROOT_PATH + '/tmp/ar.log')
begin
  require 'conf/conf'
rescue LoadError
  $logger.info "conf file not found. Terminate."
  exit
end

# ディレイ設定
SLEEP = [4.0, 4.5, 5.0, 5.5, 6.0]

# URL構造
URL = {}
{ 
  :login   => "login",
  :index   => "mindex",
  :hero    => "hero?oid=",
  :raid    => "a2t?vid=",
  :map     => "GameMap?",
  :mapinfo => "GameMapInfo?mapId=",
  :soldier => "s2h?vid=",
  :castle  => "mindex?vid=",
}.each{ |key, value| URL[key] = DOMAIN + value }
