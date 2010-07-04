# -*- coding: utf-8 -*-
class TargetController < ApplicationController
  
  def index
    @time_tables = TimeTable.find :all, :order => 'get_at desc', :limit => 10
    @max_time = @time_tables.first.get_at.to_s(:db)
    @min_time = @time_tables.last.get_at.to_s(:db)
    @targets = Target.find(:all, :conditions => 'name is not null', :include => 'details')
  end
  
  def show
    @target = Target.find(params[:id])
    @details = Detail.find(:all, :conditions => ["target_id = ?", params[:id]], :order => 'get_at')
  end
  
  def create
    target = Target.new :userid => params[:userid]
    if target.save
      flash[:notice] = "登録しました"
    else
      flash[:notice] = "登録できませんでした"
    end
    redirect_to :action => 'index'
  end
  
end
