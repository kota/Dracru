# -*- coding: utf-8 -*-
# ほんとうは mechanizeの箇所を分離したかった
module Core
  
  def delay
    sleep SLEEP[rand(SLEEP.length)]
  end
  
end
