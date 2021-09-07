require 'active_record'

environment = ENV['environment']

if environment == 'development' || environment == nil
  ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: 'tubepeekdb.db')
else
  host = ENV['DATABASE_HOST']
  port = ENV['DATABASE_PORT']
  db_username = ENV['DATABASE_USERNAME']
  db_password = ENV['DATABASE_PASSWORD']
  db_name = ENV['DATABASE_NAME']

  ActiveRecord::Base.establish_connection(
    adapter: 'postgresql',
    host: host,
    port: port,
    username: db_username,
    password: db_password,
    database: db_name
  )
end

class UserMaster < ActiveRecord::Base
  self.table_name = 'usermaster'
  self.primary_key = 'id'
end

class UserFriend < ActiveRecord::Base
  self.table_name = 'userfriends'
  self.primary_key = 'id'
  belongs_to :usermaster, class_name: "UserMaster", foreign_key: :user_google_uid
end

class Video < ActiveRecord::Base
  self.table_name = 'videos'
  self.primary_key = 'id'
end

class UserVideo < ActiveRecord::Base
  self.table_name = 'uservideos'
  self.primary_key = 'id'
end
