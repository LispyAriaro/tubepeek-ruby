require 'active_record'

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: 'tubepeekdb.db')

# ActiveRecord::Base.establish_connection(
#   adapter: 'postgresql',
#   host: 'localhost',
#   username: 'my_user',
#   password: 'p@ssw0rd',
#   database: 'my_db'
# )

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
