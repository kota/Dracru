class CreateDetails < ActiveRecord::Migration
  def self.up
    create_table :details do |t|
      t.integer   :target_id
      t.timestamp :get_at
      t.integer   :ranking
      t.integer   :fame
      t.string    :race
      t.string    :guild
      t.integer   :castle
      t.integer   :population
      t.integer   :heros_num
      t.timestamps
    end
  end

  def self.down
    drop_table :details
  end
end
