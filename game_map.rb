class GameMap < ActiveRecord::Base

  def self.generate_maps(agent)
    vectors = [[-11,-9],[-11,0],[11,9],
               [0,-9],[0,0],[0,9],
               [11,-9],[11,0],[11,9]]
    vectors.each do |xy|
      xp = (CATSLE_X.to_i + xy[0]).to_s
      yp = (CATSLE_Y.to_i + xy[1]).to_s
      doc = Nokogiri.HTML(agent.get(URL[:map] + "xp=#{xp}&yp=#{yp}").body)
      doc.xpath("//div[@class='cells']/ul/li/a").each do |anchor|
        if(anchor['onmouseover'].split(',')[1] =~ /'(山地|丘陵|湿地|森林)'/)
          map_type = $1
          x,y = anchor['onmouseover'].match(/showCityInfo\('([0-9-]+)\|([0-9-]+)/)[1..2]
          map_id = anchor['href'].match(/GameMapInfo\?mapId=([0-9]+)/)[1]
          GameMap.create({:x => x,:y => y,:url => anchor['href'], :mapid => map_id})
        end
      end
    end
  end

  def self.get_available_map
    if map = GameMap.find(:first,:conditions => 'visited = 0')
      map.visited = 1
      map.save!
      return map
    else 
      return nil
    end
  end

end
