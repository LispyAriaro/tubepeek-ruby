require 'active_record'
require 'sinatra/base'
require 'faye/websocket'
require 'json'
require 'yaml'
require_relative './migrations/run_migrations'
require_relative './entities'
require_relative './utils'

module TubePeek
  def self.start_server
    if ENV['YOUTUBE_API_KEY'] == nil
      # File::open('dev-env.yaml') do |config_file|
      #   config = YAML::load(config_file)
      #   puts config
      #   puts config['YOUTUBE_API_KEY']
      # end

      config_file = File.open('dev-env.yaml')
      config = YAML::load(config_file)
      puts config
      puts config['YOUTUBE_API_KEY']
      if config['YOUTUBE_API_KEY'] == nil
        exit
      end
    end

    TubePeekMigrations::run
  end

  class MainApp < Sinatra::Base
    get "/" do
      content_type :json
      { app: "TubePeekServer - Ruby variant" }.to_json
    end
  end

  class WebSocket
    KEEPALIVE_TIME = 15 # in seconds

    def initialize(app)
      @app     = app
      @clients = []
    end

    def call(env)
      if Faye::WebSocket.websocket?(env)
        ws = Faye::WebSocket.new(env, nil, {ping: KEEPALIVE_TIME })
        ws.on :open do |event|
          p [:open, ws.object_id]
          @clients << ws
        end

        ws.on :message do |event|
          p [:message, event.data]
          json = JSON.parse(event.data)

          handle_ws_msg json, ws
          # @clients.each {|ws_item| ws_item.send(event.data) }
        end

        ws.on :close do |event|
          p [:close, ws.object_id, event.code, event.reason]
          @clients.delete(ws)
          ws = nil
        end

        # Return async Rack response
        ws.rack_response
      else
        @app.call(env)
      end
    end

    def handle_ws_msg (json, ws)
      case json['action']
      when 'TakeUserMessage'
        handle_user json, ws
      when 'UserChangedOnlineStatus'
        handle_online_status_change json, ws
      when 'MakeFriendship'
        handle_friendship json, ws
      when 'ChangedVideo'
        handle_video_change json, ws
      when 'FriendExclusion'
        handle_friend_exclusion json, ws
      when 'PING'
        ws.send '{"action": "PONG"}'
      else
        puts 'Unknown message type'
        ws.send('Unknown message type')
      end
    end

    def handle_user(json, ws_client)
      google_user_id = json['authData']['uid']
      persist_user json
    end

    def handle_online_status_change(json, ws_client)
      "{}"
    end

    def handle_video_change(json, ws_client)
      "{}"
    end

    def handle_friendship(json, ws_client)
      "{}"
    end

    def handle_friend_exclusion (json, ws_client)
      existing_friend = UserFriend.find_by(
        :user_google_uid => json['googleUserId'],
        :friend_google_uid => json['friendGoogleUserId'])

      if existing_friend != nil
        existing_friend.is_friend_excluded = json['exclude']
        existing_friend.save
      end
    end

    private
    def persist_user(user_details)
      google_user_id = user_details['authData']['uid']
      existing_user = UserMaster.find_by(:uid => google_user_id)
      # adults = User.where('age > ?', 18)
      puts existing_user

      if existing_user == nil
        UserMaster.new { |u|
          u.uid = google_user_id
          u.provider = user_details['provider']
          u.full_name = user_details['authData']['fullName']
          u.image_url = user_details['authData']['imageUrl']
        }.save
      else
        existing_user.full_name = user_details['authData']['fullName']
        existing_user.image_url = user_details['authData']['imageUrl']
        existing_user.save
      end
    end

    private
    def persist_video_watched(google_user_id, video_url, video_title)
      youtube_video_id = Utils::get_youtube_videoid video_url

      existing_user = UserMaster.find_by(:uid => google_user_id)
      if existing_user == nil
        return
      end

      existing_video = Video.find_by(:youtube_video_id => youtube_video_id)
      if existing_video == nil
        video = Video.new { |v|
          v.video_url = video_url
          v.youtube_video_id = youtube_video_id
          v.video_title = video_title
        }
        video.save

        UserVideo.new { |uv|
          uv.user_id = video_url
          uv.video_id = video.id
        }.save
      else
        existing_user_video = UserVideo.find_by(
          :user_id => existing_user.id,
          :video_id => existing_video.id
        )

        if existing_user_video == nil
          UserVideo.new { |uv|
            uv.user_id = existing_user.id
            uv.video_id = existing_video.id
          }.save
        end
      end
    end

    # private
    # def sanitize(message)
    #   json = JSON.parse(message)
    #   json.each {|key, value| json[key] = ERB::Util.html_escape(value) }
    #   JSON.generate(json)
    # end
  end
end

TubePeek::start_server
