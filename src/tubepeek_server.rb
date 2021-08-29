require 'active_record'
require 'sinatra/base'
require 'faye/websocket'
require 'json'
require_relative './migrations/run_migrations'

module TubePeek
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

          handle_ws_msg json, nil, ws
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

    def handle_ws_msg (json, db_con, ws)
      case json 'title'
      when 'TakeUserMessage'
        handle_user json, nil, ws
      when 'UserChangedOnlineStatus'
        handle_online_status_change json, nil, ws
      when 'MakeFriendship'
        handle_friendship json, nil, ws
      when 'ChangedVideo'
        handle_video_change json, nil, ws
      when 'FriendExclusion'
        handle_friend_exclusion json, nil, ws
      when 'PING'
        ws.send '{"action": "PONG"}'
      else
        puts 'Unknown message type'
        ws.send('Unknown message type')
      end
    end

    def handle_user (jsojsonn_str, db_con, ws_client)
    end

    def handle_online_status_change (json_str, db_con, ws_client)
    end

    def handle_friendship (json_str, db_con, ws_client)
    end

    def handle_video_change (json_str, db_con, ws_client)
    end

    def handle_friend_exclusion (json_str, db_con, ws_client)
    end

    # private
    # def sanitize(message)
    #   json = JSON.parse(message)
    #   json.each {|key, value| json[key] = ERB::Util.html_escape(value) }
    #   JSON.generate(json)
    # end
  end
end

TubePeekMigrations::run_migrations
