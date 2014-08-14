require 'dotenv'
Dotenv.load
require_relative 'db'

puts "Import features from #{ENV['FEATURES_FILE']}"

if ENV['DROP_TABLES'] == 'true'
  ActiveRecord::Base.connection.execute('
    DROP TABLE IF EXISTS "features";

    CREATE TABLE "features" (
      "id" varchar,
      "priority" int8,
      "name" varchar
    )
    WITH (OIDS=FALSE);
  ')
end

if File.exists?(ENV['FEATURES_FILE'])
  @features = File.read(ENV['FEATURES_FILE']).lines
  @features.each do |feature|
    matches = feature.match(/(?<id>[0-9]+)\s+(?<priority>[0-9]+)\s+(?<name>.*)/m)
    if matches
      ActiveRecord::Base.connection.execute(
        "INSERT INTO \"features\" (
           id,
           priority,
           name
         ) VALUES (
           '#{matches['id']}',
           #{matches['priority']},
           #{ActiveRecord::Base.connection.quote(matches['name'])}
         );"
      )
    else
      puts "ERROR: Feature cannot be parsed: #{feature}"
    end
  end
end
