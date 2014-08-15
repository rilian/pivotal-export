require 'dotenv'
Dotenv.load

require_relative 'db'

puts 'Assign feature_id to stories table'

ActiveRecord::Base.connection.execute("
  UPDATE stories
  SET feature_id = (
    SELECT CAST(features.id AS int8)
    FROM features
    WHERE
      (stories.labels LIKE '%f' || features.id) OR
      (stories.labels LIKE '%f' || features.id || ',')
    ORDER BY features.priority ASC
    LIMIT 1
  )
")

