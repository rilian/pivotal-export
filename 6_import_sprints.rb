require 'dotenv'
Dotenv.load
require 'byebug'

require_relative 'db'

puts 'Import Sprints'

def fake_assign_story_to_features
  puts 'Fake assign stories to features randomly'

  raw = ActiveRecord::Base.connection.execute('
    SELECT id FROM features WHERE id NOT IN (
      SELECT id FROM features
      WHERE features.id IN (
        SELECT feature_id FROM stories
      )
    );')

  feature_without_stories_ids = raw.to_a.collect{|f| f['id'] }

  raw = ActiveRecord::Base.connection.execute('
    SELECT id FROM stories WHERE feature_id IS NULL;
  ')

  story_without_feature_id_ids = raw.to_a.collect{|f| f['id'] }

  story_without_feature_id_ids.each do |story_id|
    f_id = feature_without_stories_ids.sample
    if !f_id
      raw = ActiveRecord::Base.connection.execute('
    SELECT id FROM features WHERE id NOT IN (
      SELECT id FROM features
      WHERE features.id IN (
        SELECT cast(feature_id as varchar) as id FROM stories
      )
    );')
      feature_without_stories_ids = raw.to_a.collect{|f| f['id'] }
      f_id = feature_without_stories_ids.pop
    end

    ActiveRecord::Base.connection.execute("
      UPDATE stories SET feature_id=#{f_id} WHERE id='#{story_id}';
    ")
  end
end

if ENV['FAKE_ASSIGN_STORY_TO_FEATURES'] == 'true'
  fake_assign_story_to_features
end

# Get Stories by Feature priority
raw = ActiveRecord::Base.connection.execute('
  SELECT
    stories.*,
    features.priority,
    features.id as feature_id,
    features.name as feature_name

  FROM "stories"

  LEFT OUTER JOIN features ON stories.feature_id = features.id

  WHERE stories.accepted_at IS NULL

  ORDER BY features.priority ASC, features.id ASC, stories.id ASC
;')

# Gather Stories by resource kind (backend, frontend etc)
@backend = []
@mobile = []
@frontend = []
@unassigned = []

raw.each do |record|
  if record['owner_ids'].split(',').count > 0
    record['owner_ids'].split(',').each do |id|
      if ENV['BACKEND_DEVELOPER_IDS'].split(',').any? { |dev_id| id == dev_id }
        @backend << record
      elsif ENV['FRONTEND_DEVELOPER_IDS'].split(',').any? { |dev_id| id == dev_id }
        @frontend << record
      elsif ENV['MOBILE_DEVELOPER_IDS'].split(',').any? { |dev_id| id == dev_id }
        @mobile << record
      end
    end
  else
    @unassigned << record
  end
end

puts "Backend stories    #{@backend.count}"
puts "Frontend stories   #{@frontend.count}"
puts "Mobile stories     #{@mobile.count}"
puts "Unassigned stories #{@unassigned.count}"

sprints = [{ stories: [], backend_estimate: 0, frontend_estimate: 0, mobile_estimate: 0, unassigned_estimate: 0 }]
estimate_multiplier = 1

%w[backend frontend mobile].each do |kind|
  current_sprint_id = 0

  instance_variable_get("@#{kind}").each do |story|
    # Find first sprint to put story
    puts "current_sprint_id=#{current_sprint_id} estimate=#{sprints[current_sprint_id]["#{kind}_estimate".to_sym]} story_est=#{story['estimate'].to_i*estimate_multiplier}"
    while sprints[current_sprint_id]["#{kind}_estimate".to_sym] + story['estimate'].to_i*estimate_multiplier > (ENV['SPRINT_SIZE'].to_i * ENV["#{kind.upcase}_DEVELOPER_IDS"].split(',').count)
      current_sprint_id += 1
      sprints << { stories: [], backend_estimate: 0, frontend_estimate: 0, mobile_estimate: 0, unassigned_estimate: 0 }
    end

    # Assign story
    sprints[current_sprint_id][:stories] << story
    sprints[current_sprint_id]["#{kind}_estimate".to_sym] += story['estimate'].to_i
    puts "put #{kind} story #{story['id']} into sprint #{current_sprint_id}"
    puts "sprint has #{sprints[current_sprint_id][:stories].count} stories"
  end
end

current_sprint_id = 0
while sprints[current_sprint_id][:backend_estimate] + sprints[current_sprint_id][:frontend_estimate] +
  sprints[current_sprint_id][:mobile_estimate] + sprints[current_sprint_id][:unassigned_estimate] > 0
  current_sprint_id += 1
end

max_resource_developers = [ENV['BACKEND_DEVELOPER_IDS'].split(',').count, ENV['FRONTEND_DEVELOPER_IDS'].split(',').count, ENV['MOBILE_DEVELOPER_IDS'].split(',').count].max
#sprints << { stories: [], backend_estimate: 0, frontend_estimate: 0, mobile_estimate: 0, unassigned_estimate: 0 }

@unassigned.each do |story|
  # Find first sprint to put story
  while sprints[current_sprint_id][:unassigned_estimate] + story['estimate'].to_i*estimate_multiplier > (ENV['SPRINT_SIZE'].to_i * max_resource_developers)
    current_sprint_id += 1
    sprints << { stories: [], backend_estimate: 0, frontend_estimate: 0, mobile_estimate: 0, unassigned_estimate: 0 }
  end

  # Assign story
  sprints[current_sprint_id][:stories] << story
  sprints[current_sprint_id][:unassigned_estimate] += story['estimate'].to_i
  puts "put unassigned story #{story['id']} into sprint #{current_sprint_id}"
  puts "sprint has #{sprints[current_sprint_id][:stories].count} stories"
end

if ENV['DROP_TABLES'] == 'true'
  ActiveRecord::Base.connection.execute('
    DROP TABLE IF EXISTS "sprints";

    CREATE TABLE "sprints" (
      "id" int8,
      "feature_id" int8 NULL,
      "feature_name" varchar,
      "feature_priority" int8,
      "story_id" varchar,
      "story_name" varchar,
      "story_estimate" int8,
      "story_resource" varchar
    )
    WITH (OIDS=FALSE);
  ')
end

def get_resource_from_dev_id(id)
  if ENV['BACKEND_DEVELOPER_IDS'].split(',').any? { |dev_id| id == dev_id }
    'backend'
  elsif ENV['FRONTEND_DEVELOPER_IDS'].split(',').any? { |dev_id| id == dev_id }
    'frontend'
  elsif ENV['MOBILE_DEVELOPER_IDS'].split(',').any? { |dev_id| id == dev_id }
    'mobile'
  else
    'unassigned'
  end
end

# Fill in Sprints
sprints.each_with_index do |sprint, index|
  sprint[:stories].each do |story|
    # TODO: owner_ids may be multiple
    ActiveRecord::Base.connection.execute("
      INSERT INTO sprints (
        id,
        feature_id,
        feature_name,
        feature_priority,
        story_id,
        story_name,
        story_estimate,
        story_resource
      ) VALUES (
        #{index},
        #{story['feature_id'] || 'NULL'},
        #{(ActiveRecord::Base.connection.quote((story['feature_name'] || '').strip))},
        #{story['priority'] || 'NULL'},
        '#{story['id']}',
        #{ActiveRecord::Base.connection.quote(story['name'].strip)},
        #{[story['estimate'].to_i*estimate_multiplier, 1].max},
        '#{get_resource_from_dev_id(story['owner_ids'])}'
      )
    ")
  end
end

puts 'Sprints created'
