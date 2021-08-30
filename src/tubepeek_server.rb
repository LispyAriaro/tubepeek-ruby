require 'active_record'
require 'sinatra/base'
require 'faye/websocket'
require 'json'
require 'yaml'
require_relative './migrations/run_migrations'
require_relative './entities'
require_relative './utils'
require 'videoinfo'

module TubePeek
  def self.start_server
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
          ws.online_friends = []
          @clients << ws
        end

        ws.on :message do |event|
          p [:message, event.data]
          json = JSON.parse(event.data)

          handle_ws_msg json, ws
        end

        ws.on :close do |event|
          p [:close, ws.object_id, event.code, event.reason]

          broadcast_data = {
            'action' => 'TakeFriendOnlineStatus',
            'googleUserId' => ws.googleUserId,
            'onlineState' => false
          }

          @clients.each { |ws_item|
            if ws_item.object_id == ws.object_id
              ws_item.online_friends.each {|ws_item_friend|
                ws_item_friend.send(JSON.generate broadcast_data)
              }
            end
          }
          @clients.delete_if {|ws_client| ws_client.object_id == ws.object_id }
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
      existing_friends = UserFriend.where('user_google_uid > ?', google_user_id)



    end

    def handle_online_status_change(json, ws)
      google_user_id = json['googleUserId']
      online_status = json['onlineState']

      broadcast_data = {
        'action' => 'TakeFriendOnlineStatus',
        'googleUserId' => google_user_id,
        'onlineState' => online_status
      }

      @clients.each { |ws_item|
        if ws_item.object_id == ws.object_id
          ws_item.online_friends.each {|ws_item_friend|
            ws_item_friend.send(JSON.generate broadcast_data)
          }
        end
      }
      if online_status == false
        @clients.delete_if {|ws_client| ws_client.object_id == ws.object_id }
      end

      "{}"
    end

    def handle_video_change(json, ws_client)
      video_url = json['videoUrl']
      google_user_id = json['googleUserId']

      video = VideoInfo.new(video_url)

      ws_client.currentVideo = {
        'videoUrl' => video_url,
        'title' => video.title,
        'thumbnail_url' => video.thumbnail_medium,
        'timeStampInMilliseconds' => (Time.now.to_f.round(3)*1000).to_i
      }

      user = UserMaster.find_by(:uid => google_user_id)

      broadcast_data = {
        'action' => 'TakeFriendVideoChange',
        'googleUserId' => google_user_id,
        'videoData' => {
          'videoUrl' => video_url,
          'title' => video.title,
          'thumbnail_url' => video.thumbnail_medium,
          'timeStampInMilliseconds' => (Time.now.to_f.round(3)*1000).to_i
        },
        'friendData' => {
          'full_name' => user.full_name,
          'image_url' => user.image_url,
        },
      }

      @clients.each { |ws_item|
        if ws_item.object_id == ws_client.object_id
          ws_item.online_friends.each {|ws_item_friend|
            ws_item_friend.send(JSON.generate broadcast_data)
          }
        end
      }

      persist_video_watched google_user_id video_url video.video_id video.title
      "{}"
    end

    def handle_friendship(json, ws_client)
      google_user_id = json['googleUserId']
      friend_google_user_id = json['friendGoogleUserId']

      existing_friend = UserFriend.find_by(
        :user_google_uid => google_user_id,
        :friend_google_uid => friend_google_user_id)

      if existing_friend == nil
        UserFriend.new { |uf|
          uf.user_google_uid = google_user_id
          uf.friend_google_uid = friend_google_user_id
          uf.is_friend_excluded = false
        }.save
      end

      existing_reverse_friend = UserFriend.find_by(
        :user_google_uid => friend_google_user_id,
        :friend_google_uid => google_user_id)

      if existing_reverse_friend == nil
        UserFriend.new { |uf|
          uf.user_google_uid = friend_google_user_id
          uf.friend_google_uid = google_user_id
          uf.is_friend_excluded = false
        }.save
      end

      current_user = UserMaster.find_by(:uid => google_user_id)
      friend_user = UserMaster.find_by(:uid => friend_google_user_id)

      if current_user != nil and friend_user != nil
        @clients.each { |ws_item|
          if ws_item.googleUserId == friend_google_user_id
            broadcast_data = {
              'action' => 'NewFriendOnTubePeek',
              'friendDetails' => {
                'googleUserId' => google_user_id,
                'fullName' => current_user.full_name,
                'imageUrl' => current_user.image_url
              }
            }
            ws_item.send(JSON.generate broadcast_data)
          end

          if ws_item.googleUserId == google_user_id
            broadcast_data = {
              'action' => 'NewFriendOnTubePeek',
              'friendDetails' => {
                'googleUserId' => friend_google_user_id,
                'fullName' => friend_user.full_name,
                'imageUrl' => friend_user.image_url
              }
            }
            ws_item.send(JSON.generate broadcast_data)
          end
        }
      end
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
    def persist_video_watched(google_user_id, video_url, video_id, video_title)
      existing_user = UserMaster.find_by(:uid => google_user_id)
      if existing_user == nil
        return
      end

      existing_video = Video.find_by(:youtube_video_id => video.video_id)
      if existing_video == nil
        video = Video.new { |v|
          v.video_url = video_url
          v.youtube_video_id = video.video_id
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
  end
end

TubePeek::start_server
