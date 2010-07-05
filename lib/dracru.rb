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
  :soldier => "#{DOMAIN}s2h",
}

class Dracru
  FILE_PATH = File.expand_path(File.dirname(__FILE__)) 
  COOKIES = FILE_PATH + '/cookies'
  DB = FILE_PATH + '/dracru.db'

  attr_accessor :agent,:map,:heroes

  def initialize
    @logger = Logger.new(FILE_PATH + "/dracru.log")
    # @logger = Logger.new(STDOUT)
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
      html = @agent.get(URL[:hero] + hero).body
      #doc = Nokogiri.HTML(@agent.get(URL[:hero] + hero).body)
      doc = Nokogiri::HTML.parse(html, nil, 'UTF-8')
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
        if catsle_id && map = GameMap.get_available_map
          raid(catsle_id, hero, map.x, map.y, hp_text)
        else
          @logger.info "No maps available"
        end
      else
        @logger.info "Hero:#{hero} in raid. HP #{hp_text}"
      end
    end
  end

  def raid(catsle_id, hero_id, x, y, hp_text)
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
      @logger.info "SUCCESS: Raid #{x},#{y} with hero : #{hero_id}. HP #{hp_text}"
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
end
