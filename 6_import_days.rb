require 'dotenv'
Dotenv.load
require 'byebug'

require_relative 'db'

puts 'Import Sprints'

# Cleanup
if ENV['DROP_TABLES'] == 'true'
  ActiveRecord::Base.connection.execute('
    DROP TABLE IF EXISTS "days";

    CREATE TABLE "days" (
      "id" int8,
      "feature_id" int8 NULL,
      "feature_name" varchar,
      "feature_priority" int8,
      "story_id" varchar,
      "story_project_id" varchar,
      "story_name" varchar,
      "story_estimate" int8
    )
    WITH (OIDS=FALSE);
  ')
end

# Get Stories by Feature priority
raw_stories = ActiveRecord::Base.connection.execute("
  SELECT
    stories.*,
    features.priority,
    features.id as feature_id,
    features.name as feature_name

  FROM stories

  LEFT OUTER JOIN features ON stories.feature_id = features.id

  WHERE stories.accepted_at IS NULL
    AND stories.story_type != 'release'
    AND stories.estimate > 0

  ORDER BY features.priority ASC, features.id ASC, stories.project_id ASC, stories.id ASC
;")

# Gather Stories by project into days, counting team size
def total(day, project_id)
  sum = 0
  Array.wrap(day[project_id]).each do |story|
    sum += story['estimate'].to_i
  end
  sum
end

days = []
raw_stories.each do |story|
  day_effort = ENV["#{story['project_id']}_DEVELOPERS"].to_i * ENV['WORK_DAY_HOURS'].to_f
  puts "day_effort = #{day_effort}"

  day_id = 0
  has_put_story = false
  while !has_put_story
    if days[day_id].nil?
      days << {}
    elsif total(days[day_id], story['project_id']) + story['estimate'].to_i > day_effort
      day_id += 1

      if days[day_id].nil?
        days << {}
      end

      if total(days[day_id], story['project_id']) == 0
        has_put_story = true
        days[day_id][story['project_id']] = [] if days[day_id][story['project_id']].nil?
        days[day_id][story['project_id']] << story
        puts "put #{story['project_id']} #{story['estimate']}h => day #{day_id}, now #{total(days[day_id], story['project_id'])}h"
      end
    else
      has_put_story = true
      days[day_id][story['project_id']] = [] if days[day_id][story['project_id']].nil?
      days[day_id][story['project_id']] << story
      puts "put #{story['project_id']} #{story['estimate']}h => day #{day_id}, now #{total(days[day_id], story['project_id'])}h"
    end
  end
end

puts "Total #{days.count} days"

# Fill in Days
days.each_with_index do |day, index|
  day.values.each do |project|
    project.each do |story|
      ActiveRecord::Base.connection.execute("
        INSERT INTO days (
          id,
          feature_id,
          feature_name,
          feature_priority,
          story_id,
          story_project_id,
          story_name,
          story_estimate
        ) VALUES (
          #{index},
          #{story['feature_id'] || 'NULL'},
          #{(ActiveRecord::Base.connection.quote((story['feature_name'] || '').strip))},
          #{story['priority'] || 'NULL'},
          '#{story['id']}',
          '#{story['project_id']}',
          #{ActiveRecord::Base.connection.quote(story['name'].strip)},
          #{story['estimate'].to_i}
        )
      ")
    end
  end
end

puts 'Days created'
