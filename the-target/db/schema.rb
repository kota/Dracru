# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20100703192336) do

  create_table "accounts", :force => true do |t|
    t.string   "userid"
    t.string   "password"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "details", :force => true do |t|
    t.integer  "target_id"
    t.datetime "get_at"
    t.integer  "ranking"
    t.integer  "fame"
    t.string   "race"
    t.string   "guild"
    t.integer  "castle"
    t.integer  "population"
    t.integer  "heros_num"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "targets", :force => true do |t|
    t.integer  "userid",     :null => false
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "time_tables", :force => true do |t|
    t.datetime "get_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
