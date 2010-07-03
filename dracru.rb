require 'rubygems'
require 'mechanize'
require 'hpricot'
require 'logger'
require 'yaml'
require 'conf'
#
# Define your id and password in conf.rb as following
# USERID = myuserid
# PASSWD = mypassword
#
MYHEROS = ['24762','31744','27811']
CATSLES = ['16018','21446']

class Dracru
  COOKIES = 'cookies'
  DOMAIN = "http://g03.dragon.vector.jp/"
  URL = { 
    :login => "#{DOMAIN}login",
    :index => "#{DOMAIN}mindex",
    :hero => "#{DOMAIN}hero?oid=",
    :raid  => "#{DOMAIN}a2t?vid=",
  }

  attr_accessor :agent

  def initialize
    @agent = Mechanize.new
    @agent.log = Logger.new("mech.log")
    @agent.log.level = Logger::INFO
    @agent.user_agent_alias = 'Windows IE 7'
    @agent.cookie_jar.load(COOKIES) if File.exists?(COOKIES)
    login
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
        @agent.log.info 'Logged In'
      end
    end
    @agent.cookie_jar.save_as(COOKIES)
    @agent
  end
  
  def raid(catsle_id,hero_id,x,y)
    select_hero = @agent.get(URL[:raid] + catsle_id)
    begin
      confirm = select_hero.form_with(:action => '/a2t') do |f|
        if hero_checkbutton = f.checkbox_with(:value => hero_id)
          hero_checkbutton.check
        else
          raise "Hero:#{hero_id} not available."
        end
        f.radiobuttons_with(:name => type).each{|radio| radio.check if radio.value == 2 }
        f.x = x
        f.y = y
      end.submit
      result = confirm.form_with(:name => 'form1') do |f|
        f.action = '/s2t'
      end.click_button
      @agent.log.info "SUCCESS: Raid #{x},#{y} witch hero:#{hero_id}"
    rescue => e
      @agent.log.error e.message
    end
  end

end

dracru = Dracru.new
#dracru.raid(CATSLES[1],MYHEROS[2],24,-44)
