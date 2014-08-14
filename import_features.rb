if File.exists?(ENV['FEATURES_FILE'])
  File.read(ENV['FEATURES_FILE']).lines.each do |feature|
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
