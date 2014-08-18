require 'dotenv'
Dotenv.load

require_relative 'db'

puts 'Import stories from local files'

def get_story_record(json)
  "INSERT INTO \"stories\" (
    id,
    project_id,
    feature_id,
    url,
    kind,
    story_type,
    created_at,
    updated_at,
    accepted_at,
    current_state,
    labels,
    estimate,
    name,
    description,
    requested_by_id,
    owner_ids
  ) VALUES (
    '#{json['id']}',
    #{json['project_id']},
    NULL,
    '#{json['url']}',
    '#{json['kind']}',
    '#{json['story_type']}',
    #{json['created_at']},
    #{json['updated_at']},
    #{json['accepted_at'] || 'NULL'},
    '#{json['current_state']}',
    #{ActiveRecord::Base.connection.quote(json['labels'].collect{ |l| l['name'] }.join(','))},
    #{json['estimate'] || 0},
    #{ActiveRecord::Base.connection.quote((json['name'] || ''))},
    #{ActiveRecord::Base.connection.quote((json['description'] || ''))},
    #{json['requested_by_id'] || 0},
    '#{(json['owner_ids'] + Array.wrap(json['owned_by_id'])).uniq.join(',')}'
  );"
end

if ENV['DROP_TABLES'] == 'true'
  ActiveRecord::Base.connection.execute('
    DROP TABLE IF EXISTS "stories";

    CREATE TABLE "stories" (
      "id" varchar,
      "project_id" int8,
      "feature_id" int8,
      "url" varchar,
      "kind" varchar,
      "story_type" varchar,
      "created_at" int8,
      "updated_at" int8,
      "accepted_at" int8 NULL,
      "current_state" varchar,
      "labels" varchar,
      "estimate" int8,
      "name" text,
      "description" text,
      "requested_by_id" int8,
      "owner_ids" varchar
    )
    WITH (OIDS=FALSE);
  ')
end

# if ENV['GUESSTIMATE_FEATURES'] = 'true'
#   puts 'Add guesstimated stories'
#
#   raw_features_without_stories = ActiveRecord::Base.connection.execute('
#     SELECT *
#     FROM features
#     WHERE id NOT IN (SELECT feature_id FROM stories WHERE feature_id > 0 AND accepted_at IS NULL)
#     ORDER BY priority ASC, id ASC
#   ')
#
#   raw_features_without_stories.each do |feature|
#     puts "feature #{feature['id']}"
#     ENV['PROJECT_IDS'].split(',').each do |project_id|
#       puts "project #{project_id}"
#       total_hours = ENV["#{project_id}_FEATURE_GESSTIMATE_HOURS"].to_i
#       puts "total hours = #{total_hours}"
#       while total_hours > 0
#         @stories << {
#           "kind" => "story",
#           "id" => @stories.last['id'].to_i + 1,
#           "created_at" => 1394886190000,
#           "updated_at" => 1394958166000,
#           "estimate" => [total_hours, ENV['WORK_DAY_HOURS'].to_i].min,
#           "story_type" => "feature",
#           "name" => "DO #{feature['name']}",
#           "description" => "need some discussion",
#           "current_state" => "unscheduled",
#           "requested_by_id" => @stories.last['requested_by_id'],
#           "project_id" => project_id.to_i,
#           "url" => "",
#           "owner_ids" => [0],
#           "labels" => [{"name" => "f#{feature['id']}"}],
#           "owned_by_id" => 0
#         }
#         puts "added story of #{[total_hours, ENV['WORK_DAY_HOURS'].to_i].min} hours"
#         total_hours -= ENV['WORK_DAY_HOURS'].to_i
#       end
#     end
#   end
# end

@stories.each do |story|
  ActiveRecord::Base.connection.execute(get_story_record(story))
end
