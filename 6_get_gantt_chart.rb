require 'dotenv'
Dotenv.load
require 'byebug'

require_relative 'db'

puts 'Produce Gantt chart'

raw = ActiveRecord::Base.connection.execute('
  SELECT
    stories.*,
    features.priority,
    features.id as feature_id

  FROM "stories"

  JOIN features ON stories.feature_id = CAST(features.id AS int8)

  ORDER BY features.priority ASC, features.id ASC, stories.id ASC
')

@accepted = []
@backend = []
@mobile = []
@frontend = []
@unassigned = []

raw.each do |record|
  if record['accepted_at']
    @accepted << record
  elsif ENV['BACKEND_DEVELOPER_IDS'].split(',').any? { |dev_id| record['owner_ids'].include?(dev_id) }
    @backend << record
  elsif ENV['FRONTEND_DEVELOPER_IDS'].split(',').any? { |dev_id| record['owner_ids'].include?(dev_id) }
    @frontend << record
  elsif ENV['MOBILE_DEVELOPER_IDS'].split(',').any? { |dev_id| record['owner_ids'].include?(dev_id) }
    @mobile << record
  else
    @unassigned << record
  end
end

puts "Accepted stories   #{@accepted.count}"
puts "Backend stories    #{@backend.count}"
puts "Frontend stories   #{@frontend.count}"
puts "Mobile stories     #{@mobile.count}"
puts "Unassigned stories #{@unassigned.count}"

sprints = [{ stories: [], backend_estimate: 0, frontend_estimate: 0, mobile_estimate: 0, unassigned_estimate: 0 }]
sprint_size_for_developer = 24

%w[backend frontend mobile].each do |kind|
  current_sprint_id = 0

  instance_variable_get("@#{kind}").each do |story|
    # Find first sprint to put story
    while sprints[current_sprint_id]["#{kind}_estimate".to_sym] + story['estimate'].to_i > (sprint_size_for_developer * ENV["#{kind.upcase}_DEVELOPER_IDS"].split(',').count)
      current_sprint_id += 1
      sprints << { stories: [], backend_estimate: 0, frontend_estimate: 0, mobile_estimate: 0, unassigned_estimate: 0 }
    end

    # Assign story
    puts "can put story #{story['id']} into sprint #{current_sprint_id}"
    sprints[current_sprint_id][:stories] << story
    sprints[current_sprint_id]["#{kind}_estimate".to_sym] += story['estimate'].to_i
    puts "put story #{story['id']} into sprint #{current_sprint_id}"
    puts "sprint #{kind} estimate is #{sprints[current_sprint_id]["#{kind}_estimate".to_sym]}"
    puts "sprint #{kind} estimate max is #{sprint_size_for_developer * ENV["#{kind.upcase}_DEVELOPER_IDS"].split(',').count}"
    puts "sprint has #{sprints[current_sprint_id][:stories].count} stories"
  end
end

current_sprint_id = sprints.count
total_developers = ENV['BACKEND_DEVELOPER_IDS'].split(',').count + ENV['FRONTEND_DEVELOPER_IDS'].split(',').count + ENV['MOBILE_DEVELOPER_IDS'].split(',').count
sprints << { stories: [], backend_estimate: 0, frontend_estimate: 0, mobile_estimate: 0, unassigned_estimate: 0 }

@unassigned.each do |story|
  # Find first sprint to put story
  while sprints[current_sprint_id][:unassigned_estimate] + story['estimate'].to_i > (sprint_size_for_developer * total_developers)
    current_sprint_id += 1
    sprints << { stories: [], backend_estimate: 0, frontend_estimate: 0, mobile_estimate: 0, unassigned_estimate: 0 }
  end

  # Assign story
  puts "can put story #{story['id']} into sprint #{current_sprint_id}"
  sprints[current_sprint_id][:stories] << story
  sprints[current_sprint_id][:unassigned_estimate] += story['estimate'].to_i
  puts "put story #{story['id']} into sprint #{current_sprint_id}"
  puts "sprint unassigned estimate is #{sprints[current_sprint_id][:unassigned_estimate]}"
  puts "sprint unassigned estimate max is #{sprint_size_for_developer * total_developers}"
  puts "sprint has #{sprints[current_sprint_id][:stories].count} stories"
end

sprints.each do |sprint|
  puts sprint.inspect
end

puts 'Done'
