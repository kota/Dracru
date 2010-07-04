# -*- coding: utf-8 -*-
require 'mechanize'

class Target < ActiveRecord::Base
  has_many :details
  
  validates_uniqueness_of   :userid
  validates_numericality_of :userid
  
  

  class << self
    DOMAIN = "http://g03.dragon.vector.jp/"
    COOKIES = '/tmp/dracookies'
    URL = { 
      :login => "#{DOMAIN}login",
      :index => "#{DOMAIN}mindex",
      :hero => "#{DOMAIN}hero?oid=",
      :raid  => "#{DOMAIN}a2t?vid=",
      :user  => "#{DOMAIN}userview?userid=",
    }
    
    def crowl
      get_at = Time.now.beginning_of_day + Time.now.hour.hours
      TimeTable.create :get_at => get_at
      agent = Mechanize.new
      agent.user_agent_alias = 'Windows IE 7'
      agent.cookie_jar.load(COOKIES) if File.exists?(COOKIES)
      
      account = Account.find :first
      agent = login(agent,  account.userid, account.password)
      
      Target.find(:all).each do |target|
        html = agent.get(URL[:user] + target.userid.to_s).body
        doc = Nokogiri::HTML.parse(html, nil, 'UTF-8')
        tds = (doc/'div.u_info'/'table.t2').xpath('//td')
        strs = []
        tds.each { |e| strs << e.text }
        
        if target.name.blank?
          ths = (doc/'div.u_info'/'table.t2'/'tr'/'th')
          strs_n = []
          ths.each { |e| strs_n << e.text }
          target.name = get_name(strs_n)
          target.save
        end
        target.details.create(
                              :get_at     => get_at,
                              :ranking    => get_num(/ランキング/, strs).scan(/\d/).join(''),
                              :fame       => get_num(/名声値/, strs).scan(/\d/).join(''),
                              :race       => get_num(/種族/, strs).gsub(' ', ''),
                              :guild      => get_num(/ギルド/, strs),
                              :castle     => get_num(/城の数/, strs).scan(/\d/).join(''),
                              :population => get_num(/人口/, strs).scan(/\d/).join(''),
                              :heros_num  => (doc/'div.u_info'/'table.t2'/'td.n'/'img').size
                            )
        
      end
    end
    
    private
    
    def get_name(strs)
      name = nil
      strs.each do |v|
        if v =~ /プレイヤー情報/
          name = v
          break
        end
      end
      name.split('：')[1]
    end
    
    def get_num(reg, strs)
      index = nil
      strs.each_with_index do |v, i|
        if v =~ reg
          index = i
          break
        end
      end
      strs[index+1]
    end
    
    def find_fame
      
    end
    
    def login(agent, userid, password)
      unless URL[:index] == agent.get(URL[:index]).uri.to_s
        login_page = agent.get "http://dragon.vector.jp/member/gamestart.php?s=g03"
        server_login = login_page.form_with(:action => '/dragon/login/') do |f|
          f.loginid  = userid
          f.password = password
        end.click_button
        server_login.form_with(:action => URL[:login]).submit
        unless URL[:index] == agent.page.uri.to_s
          raise "Logged In Fail"
        else
          
        end
      end
      agent.cookie_jar.save_as(COOKIES)
      agent
    end
    
  end
  
  
end
