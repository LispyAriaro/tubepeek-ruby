require_relative './init_db_schema'

module TubePeekMigrations
  def self.run
    puts 'Running database migrations ...'
    CreateUserTable.migrate(:up)
    CreateUserFriendTable.migrate(:up)
    CreateVideoTable.migrate(:up)
    CreateUserVideoTable.migrate(:up)
    #--
  end
end
