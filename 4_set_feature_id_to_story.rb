require 'dotenv'
Dotenv.load

require_relative 'db'

puts 'Assign feature_id to stories table'

ActiveRecord::Base.connection.execute("
  UPDATE stories
  SET feature_id = (
    SELECT features.id
    FROM features
    WHERE
      (stories.labels LIKE '%f' || CAST(features.id as varchar)) OR
      (stories.labels LIKE '%f' || CAST(features.id as varchar) || ',')
    ORDER BY features.priority ASC
    LIMIT 1
  )
")

