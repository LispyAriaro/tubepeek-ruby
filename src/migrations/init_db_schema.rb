require 'active_record'

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: 'tubepeekdb.db')

class CreateUserTable < ActiveRecord::Migration[5.2]
  def up
    unless ActiveRecord::Base.connection.table_exists?(:usermaster)
      create_table :usermaster do |table|
        table.string :uid
        table.string :full_name
        table.string :image_url
        table.timestamps
      end
    end
  end

  def down
    if ActiveRecord::Base.connection.table_exists?(:usermaster)
      drop_table :usermaster
    end
  end
end

class CreateUserFriendTable < ActiveRecord::Migration[5.2]
  def up
    unless ActiveRecord::Base.connection.table_exists?(:userfriends)
      create_table :userfriends do |table|
        table.string :user_google_uid
        table.string :friend_google_uid
        table.boolean :is_friend_excluded
        table.timestamps
      end
    end
  end

  def down
    if ActiveRecord::Base.connection.table_exists?(:userfriends)
      drop_table :userfriends
    end
  end
end

class CreateVideoTable < ActiveRecord::Migration[5.2]
  def up
    unless ActiveRecord::Base.connection.table_exists?(:videos)
      create_table :videos do |table|
        table.string :video_url
        table.string :youtube_video_id
        table.string :video_title
        table.timestamps
      end
    end
  end

  def down
    if ActiveRecord::Base.connection.table_exists?(:videos)
      drop_table :videos
    end
  end
end

class CreateUserVideoTable < ActiveRecord::Migration[5.2]
  def up
    unless ActiveRecord::Base.connection.table_exists?(:uservideos)
      create_table :uservideos do |table|
        table.integer :user_id
        table.integer :video_id
        table.timestamps
      end
    end
  end

  def down
    if ActiveRecord::Base.connection.table_exists?(:uservideos)
      drop_table :uservideos
    end
  end
end
