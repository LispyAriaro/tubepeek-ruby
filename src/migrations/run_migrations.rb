require_relative './init_db_schema'

module TubePeekMigrations
  def self.run_migrations
    puts 'Inside run_migrations'
    CreateUserTable.migrate(:up)
    CreateUserFriendTable.migrate(:up)
    CreateVideoTable.migrate(:up)
    CreateUserVideoTable.migrate(:up)
    #--
  end
end
