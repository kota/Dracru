# -*- coding: utf-8 -*-
class GameMap < ActiveRecord::Base
  include Core
  
  class << self
    include Core
    def generate_maps(agent)
      get_centers_of_neighbour(CATSLE_X.to_i,CATSLE_Y.to_i,RAID_DISTANCE).each do |coord|
        html = agent.get(URL[:map] + "xp=#{coord[:x]}&yp=#{coord[:y]}").body
        doc = Nokogiri::HTML.parse(html, nil, 'UTF-8')
        sleep 0.5
        doc.xpath("//div[@class='cells']/ul/li/a").each do |anchor|
          if(anchor['onmouseover'].split(',')[1] =~ /'(山地|丘陵|湿地|森林|悪魔城)'/)
            map_type = $1
            akuma = false
            akuma = true if map_type == "悪魔城"
            x, y = anchor['onmouseover'].match(/showCityInfo\('([0-9-]+)\|([0-9-]+)/)[1..2]
            map_id = anchor['href'].match(/GameMapInfo\?mapId=([0-9]+)/)[1]
            map_data = {:x => x, :y => y, :mapid => map_id, :map_type => map_type, :akuma => akuma}
            GameMap.create(map_data)
            $logger.info "map created #{map_data}"
          end
        end
      end
    end

    def get_available_map(agent)
      now = Time.now
      if AKUMA
        # 60分以内にチェックした悪魔城は対象外
        conditions = ['akuma_checked_at < ? and visited_at != ?', 60.minutes.ago, now.beginning_of_day]
        order = "akuma desc, random()" 
      else 
        conditions = ['visited_at != ?', now.beginning_of_day]
        order = "random()"
      end
      # 30回マップ探索してダメならあきらめる
      for i in 1..30
        map = GameMap.find(:first, :conditions => conditions,:order => order)
        if map
          html = agent.get(URL[:mapinfo] + map.mapid).body
          doc = Nokogiri::HTML.parse(html, nil, 'UTF-8')
          text = doc.xpath("//div[@class='container']/div[@class='col1']/div[@class='cz_info']/h1").text
          delay
          if text.split('(')[0] == '悪魔城廃墟'
            map.no_akuma!
          else
            return map
          end
        end
      end
      return nil
    end
  end
  
  def visit!
    self.visited_at = now.beginning_of_day
    self.map.save!
  end
  
  def no_akuma!
    self.akuma_checked_at = Time.now
    self.save
    $logger.info "Map (#{map.x}|#{map.y}), 悪魔城廃墟 tt"
  end

  #distance = 画面単位ではかった距離
  # ex. distance = 1
  # * * *
  # * c *
  # * * *
  #
  # ex. ditance = 2
  # * * * * *
  # *       *
  # *   c   *
  # *       *
  # * * * * *
  #
  # return 上図*の画面の中心座標の配列
  #
  def self.get_centers_of_neighbour(center_x, center_y, distance)
    centers = []
    v_dist_in_grids = distance * 9
    h_dist_in_grids = distance * 11
    (distance*2+1).times do |i|
      v_diff   = i*9
      h_diff = i*11
      centers.push({:x => center_x-h_dist_in_grids+h_diff, :y => center_y-v_dist_in_grids})
      centers.push({:x => center_x-h_dist_in_grids,        :y => center_y-v_dist_in_grids+v_diff})
      centers.push({:x => center_x+h_dist_in_grids-h_diff, :y => center_y+v_dist_in_grids})
      centers.push({:x => center_x+h_dist_in_grids,        :y => center_y+v_dist_in_grids-v_diff})
    end
    centers.uniq
  end

end
