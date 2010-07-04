class GameMap < ActiveRecord::Base

  def self.generate_maps(agent)
    vectors = [[-22, -18],
               [-22,  18],
               [22,  -18],
               [22,   18],
               [-33,  9],
               [-33,  0],
               [-33, -9],
               [33,   9],
               [33,   0],
               [33,  -9],
               [-11, 27],
               [0,   27],
               [11,  27],
               [-11,-27],
               [0,  -27],
               [11, -27]]
    vectors.each do |xy|
      xp = (CATSLE_X.to_i + xy[0]).to_s
      yp = (CATSLE_Y.to_i + xy[1]).to_s
      doc = Nokogiri.HTML(agent.get(URL[:map] + "xp=#{xp}&yp=#{yp}").body)
      sleep 0.5
      doc.xpath("//div[@class='cells']/ul/li/a").each do |anchor|
        if(anchor['onmouseover'].split(',')[1] =~ /'(山地|丘陵|湿地|森林)'/)
          map_type = $1
          x,y = anchor['onmouseover'].match(/showCityInfo\('([0-9-]+)\|([0-9-]+)/)[1..2]
          map_id = anchor['href'].match(/GameMapInfo\?mapId=([0-9]+)/)[1]
          GameMap.create({:x => x,:y => y,:mapid => map_id})
        end
      end
    end
  end

  def self.get_available_map
    if map = GameMap.find(:first,:conditions => ['visited_at is null or visited_at != ?',Time.now.beginning_of_day],:order => 'random()')
      map.visited_at = Time.now.beginning_of_day
      map.save!
      return map
    else 
      return nil
    end
  end

end
