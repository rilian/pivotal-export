@stories.each do |story|
  ActiveRecord::Base.connection.execute(get_story_record(story))
end
