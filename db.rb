require 'dotenv'
Dotenv.load
require 'active_record'

ActiveRecord::Base.establish_connection({
  adapter: 'postgresql',
  encoding: 'unicode',
  database: ENV['DATABASE_NAME'],
  host: 'localhost'
})
