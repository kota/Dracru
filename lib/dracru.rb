# -*- coding: utf-8 -*-
require 'rubygems'
require 'mechanize'
require 'logger'
require 'yaml'
require 'sqlite3'
require 'active_record'
require 'lib/game_map'
require 'conf'

DOMAIN = "http://g03.dragon.vector.jp/"
URL = { 
  :login => "#{DOMAIN}login",
  :index => "#{DOMAIN}mindex",
  :hero => "#{DOMAIN}hero?oid=",
  :raid  => "#{DOMAIN}a2t?vid=",
  :map   => "#{DOMAIN}GameMap?"
}

class Dracru
  COOKIES = 'cookies'
  DB = 'dracru.db'

  attr_accessor :agent,:map,:heroes

  def initialize
    @logger = Logger.new(STDOUT)
    @agent = Mechanize.new
    @agent.log = Logger.new("mech.log")
    @agent.log.level = Logger::INFO
    @agent.user_agent_alias = 'Windows IE 7'
    @agent.cookie_jar.load(COOKIES) if File.exists?(COOKIES)
    login
    prepare_map_db  
  end

  def prepare_map_db
    unless File.exists?(DB)
      SQLite3::Database.new(DB)
    end
    ActiveRecord::Base.establish_connection(
      :adapter => 'sqlite3',
      :database => DB
    )
    unless GameMap.table_exists?
      ActiveRecord::Base.connection.create_table(:game_maps) do |t|
        t.column :mapid, :string
        t.column :x, :integer
        t.column :y, :integer
        t.column :visited_at, :timestamp
      end
      GameMap.generate_maps(@agent)
    end
  end

  def login
    unless URL[:index] == @agent.get(URL[:index]).uri.to_s
      @agent.log.info 'Logging'
      login_page = @agent.get "http://dragon.vector.jp/member/gamestart.php?s=g03"
      server_login = login_page.form_with(:action => '/dragon/login/') do |f|
        f.loginid  = USERID
        f.password = PASSWD
      end.click_button
      server_login.form_with(:action => URL[:login]).submit
      unless URL[:index] == @agent.page.uri.to_s
        raise "Logged In Fail"
      else
        @logger.info 'Logged In new session'
      end
    else
      @logger.info 'Logge In using cookies'
    end
    @agent.cookie_jar.save_as(COOKIES)
    @agent
  end

  def raid_if_possible
    MYHEROS.each do |hero|
      doc = Nokogiri.HTML(@agent.get(URL[:hero] + hero).body)
      sleep 0.5
      if doc.xpath("//div[@class='hero_a']/ul/li/a[@href='/heroreturn?oid=#{hero}']").empty? #待機中？
        hp_text = doc.xpath("//div[@class='hero_b']/table[2]/tr[1]/td").text
        hp,max_hp = /([0-9]+)\/([0-9]+)/.match(hp_text)[1..2]
        catsle_id = nil
        if (hp.to_f / max_hp.to_f > 1.0 / STOP_HUNT_HP_BORDER) #HPは x 分の１以上?
          catsle_link = doc.xpath("//div[@class='hero_a']/ul/li/a").each do |anchor|
            if anchor['href'] =~ /\/mindex\?vid=([0-9]+)/
              catsle_id = $1
            end 
          end
          if catsle_id && map = GameMap.get_available_map
            raid(catsle_id,hero,map.x,map.y)
          else
            @logger.info "No maps available"
          end
        end
      else
        @logger.info "Hero:#{hero} in raid"
      end
    end
  end

  def raid(catsle_id,hero_id,x,y)
    select_hero = @agent.get(URL[:raid] + catsle_id)
    sleep 0.5
    begin
      confirm = select_hero.form_with(:action => '/a2t') do |f|
        if hero_checkbutton = f.checkbox_with(:value => hero_id)
          hero_checkbutton.check
        else
          raise "Hero:#{hero_id} not available."
        end
        f.radiobuttons_with(:name => 'type').each{|radio| radio.check if radio.value == 2 }
        f.x = x
        f.y = y
      end.submit
      result = confirm.form_with(:name => 'form1') do |f|
        f.action = '/s2t'
      end.click_button
      @logger.info "SUCCESS: Raid #{x},#{y} with hero:#{hero_id}"
    rescue => e
      @logger.error e.message
      @agent.log.error e.message
    end
  end
end
