require 'active_record'
require 'sinatra/base'
require 'faye/websocket'
require 'json'
require 'yaml'
require_relative './migrations/run_migrations'
require_relative './entities'

module Utils
  def self.get_youtube_videoid(video_url)
    video_url
  end
end
