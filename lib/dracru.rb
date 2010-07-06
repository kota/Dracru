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
  :map   => "#{DOMAIN}GameMap?",
  :mapinfo => "#{DOMAIN}GameMapInfo?mapId=",
  :soldier => "#{DOMAIN}s2h",
  :castle => "#{DOMAIN}mindex?vid=",
}
SLEEP = [4.0, 4.5, 5.0, 5.5, 6.0]
class Dracru
  FILE_PATH = File.expand_path(File.dirname(__FILE__)) 
  COOKIES = FILE_PATH + '/cookies'
  DB = FILE_PATH + '/dracru.db'

  attr_accessor :agent,:map,:heroes

  def initialize
    @logger = Logger.new(FILE_PATH + "/dracru.log")
    @logger.info "---" + Time.now.strftime("%m/%d %H:%M")
    
    @agent = Mechanize.new
    @agent.log = Logger.new(FILE_PATH + "/mech.log")
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
        t.column :map_type, :string
        t.column :akuma, :bool, :default => false
        t.column :x, :integer
        t.column :y, :integer
        t.column :visited_at, :timestamp, :default => '1980-1-1'
        t.column :akuma_checked_at, :timestamp, :default => '1980-1-1'
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
      @logger.info 'Logged In using cookies'
    end
    @agent.cookie_jar.save_as(COOKIES)
    @agent
  end

  def raid_if_possible
    MYHEROS.each do |hero|
      doc = nokogiri_parse(URL[:hero] + hero)
      hp_text = doc.xpath("//div[@class='hero_b']/table[2]/tr[1]/td").text
      hp, max_hp = /([0-9]+)\/([0-9]+)/.match(hp_text)[1..2]
      sleep 0.5
      if doc.xpath("//div[@class='hero_a']/ul/li/a[@href='/heroreturn?oid=#{hero}']").empty? #待機中？
        catsle_id = nil
        # HPが満タンでユニットが0なら出撃しない(復活直後)
        # TODO ユニットを配置して出撃できるようにすること
        if hp >= max_hp && !has_soldier?(hero)
          @logger.info("Hero:#{hero} has max hp and no soldier.")
          next
        end
        #HPは x 分の１以下の場合はユニットを0にして出撃
        if (hp.to_f / max_hp.to_f <= 1.0 / STOP_HUNT_HP_BORDER)
          reset_soldier(hero)
        end
        catsle_link = doc.xpath("//div[@class='hero_a']/ul/li/a").each do |anchor|
          if anchor['href'] =~ /\/mindex\?vid=([0-9]+)/
            catsle_id = $1
          end 
        end
        if catsle_id && map = GameMap.get_available_map(agent)
          raid(catsle_id, hero, map, hp_text)
        else
          @logger.info "No maps available"
        end
      else
        @logger.info "Hero:#{hero} in raid. HP #{hp_text}"
      end
    end
  end

  def raid(catsle_id, hero_id, map, hp_text)
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
        f.x = map.x
        f.y = map.y
      end.submit
      result = confirm.form_with(:name => 'form1') do |f|
        f.action = '/s2t'
      end.click_button
      @logger.info "SUCCESS: Raid #{map.x},#{map.y} (#{map.map_type}) with hero : #{hero_id}. HP #{hp_text}"
    rescue => e
      @logger.error e.message
      @agent.log.error e.message
    end
  end
  
  # ユニットを0にする
  def reset_soldier(hero_id)
    @logger.info "Reset soldier: #{hero_id}"
    set_soldier(hero_id, 's_none.gif', 0)
  end

  # ユニットが0かどうかを返す
  def has_soldier?(hero_id)
    soldier_page.form_with(:action => '/SoldierDistributeForm') do |form|
      return form.fields_with(:name => "heroamount#{hero_id}").any? do |f|
        f.value.to_i != 0
      end
    end
  end
  
  def set_soldier(hero_id, type, quantity)
    i = quantity / 7
    j = quantity % 7
    soldier_page.form_with(:action => '/SoldierDistributeForm') do |form|
      form.fields_with(:name => "herosoldier#{hero_id}").each do |f|
        f.value = type
      end
      form.fields_with(:name => "heroamount#{hero_id}").each do |f|
        f.value = i
        if j > 0
          f.value += 1
          j -= 1
        end
      end
    end.click_button
  end

  # 兵士配備画面のキャッシュ
  def soldier_page
    @soldier_page ||= @agent.get(URL[:soldier])
  end
  
  # 所有する英雄のIDを返す
  def get_hero_ids
    ids = []
    doc = nokogiri_parse(URL[:hero])
    
    #something
    
    ids
  end
  
  # 所有する城のIDを返す
  def get_castle_ids
    ids = []
    doc = nokogiri_parse(URL[:index])
    
    #something
    
    ids
  end
  
  # 対象の城の座標を返す
  def get_xy(castle_id)
    xy = {}
    doc = nokogiri_parse(URL[:castle])
    
    #something
    
    xy[:x] = x
    xy[:y] = y
    xy
  end
  
  
  private
  
  def nokogiri_parse(url)
    html = @agent.get(url).body
    Nokogiri::HTML.parse(html, nil, 'UTF-8')
  end
end
