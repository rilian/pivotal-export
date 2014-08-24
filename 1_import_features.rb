require 'dotenv'
Dotenv.load
require 'byebug'

require_relative 'db'

puts "Import features from #{ENV['FEATURES_FILE']}"

if ENV['DROP_TABLES'] == 'true'
  ActiveRecord::Base.connection.execute('
    DROP TABLE IF EXISTS "features";

    CREATE TABLE "features" (
      "id" int8,
      "priority" int8,
      "name" varchar
    )
    WITH (OIDS=FALSE);
  ')
end

if File.exists?(ENV['FEATURES_FILE'])
  @features = File.read(ENV['FEATURES_FILE']).lines
  @features.each_with_index do |feature, index|
    matches = feature.match(/(?<name>.*)(\t*\d{0,1}\t*\d{0,1}\t)(?<priority>[0-9]+)/m)

    if matches
      ActiveRecord::Base.connection.execute(
        "INSERT INTO \"features\" (
           id,
           priority,
           name
         ) VALUES (
           #{index},
           #{matches['priority']},
           #{ActiveRecord::Base.connection.quote(matches['name'].gsub(/\d+/, '').strip)}
         );"
      )
    else
      puts "INFO: Feature cannot be parsed: #{feature}"
    end
  end
end
