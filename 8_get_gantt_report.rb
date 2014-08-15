require 'dotenv'
Dotenv.load
require 'byebug'
require 'date'

require_relative 'db'

puts 'Produce Gantt Chart report'

# Prepare template
f = File.open('tmp/gantt.html', 'w')
f.write('
<html>
  <head>
    <title>Gantt</title>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
  </head>
  <body>
    <table border="1">
      <tr>
        <th></th>
        <th></th>
        <th></th>
        <th>Sprint &rarr;</th>')

raw_sprints_count = ActiveRecord::Base.connection.execute('SELECT COUNT(DISTINCT id) FROM sprints')
sprints_count = raw_sprints_count.to_a.first['count'].to_i

sprints_count.times do |i|
  f.write "<th colspan=\"7\">#{i + 1}</th>"
end

f.write('
      <tr>
        <th></th>
        <th></th>
        <th></th>
        <th>Date &rarr;</th>')

def date_of_next(day)
  date  = Date.parse(day)
  delta = date > Date.today ? 0 : 7
  date + delta
end

next_start_of_week_date = date_of_next('Monday')
days = []
current_date = next_start_of_week_date
(sprints_count * 7).times do
  days << current_date
  current_date = current_date + 1.day
end

days.each { |day| f.write "<th>#{day.strftime('%d %b')}</th>" }

f.write('</tr>
      <tr>
        <th>Feature</th>
        <th>ID</th>
        <th>Priority</th>
        <th>Estimated Duration</th>')

days.each { |day| f.write "<td>#{day.strftime('%a')}</td>" }

f.write('</tr>')

# Take prioritized Features that have Stories that split to Sprints
raw_features = ActiveRecord::Base.connection.execute('
  SELECT *
  FROM features
  WHERE id IN (SELECT feature_id FROM stories WHERE feature_id > 0 AND accepted_at IS NULL)
  ORDER BY priority ASC, id ASC
')

global_taken_days = []
total_duration = 0

raw_features.each do |feature|
  f.write('<tr>')

  f.write("<td>#{feature['name']}</td>")
  f.write("<td>#{feature['id']}</td>")
  f.write("<td>#{feature['priority']}</td>")

  # total duration
  raw_duration = ActiveRecord::Base.connection.execute("
    SELECT SUM(story_estimate) as sum FROM sprints WHERE feature_id=#{feature['id']}
")
  duration = raw_duration.to_a.first['sum'].to_i
  total_duration += duration
  f.write("<td>#{duration}</td>")

  # space
  f.write('<td></td>' * global_taken_days.count)

  #
  raw_stories = ActiveRecord::Base.connection.execute("
    SELECT * FROM sprints WHERE feature_id=#{feature['id']}
  ")

  def total_day_estimate(day, kind)
    total = 0
    day[kind.to_s.to_sym].each do |story|
      total = total + story['story_estimate'].to_i if story['story_resource'] == kind.to_s
    end
    total
  end

  feature_days = []
  feature_days << global_taken_days.last if global_taken_days.last
  current_day = 0
  raw_stories.each do |story|
    if feature_days[current_day].nil?
      puts 'create day'
      feature_days << { backend: [], frontend: [], mobile: [], unassigned: [] }
    end

    if total_day_estimate(feature_days.last, story['story_resource']) + story['story_estimate'].to_i <= 8
      puts "put #{story['story_estimate']}h #{story['story_resource']} story into day #{current_day}"
      feature_days.last[story['story_resource'].to_sym] << story
    else
      puts 'create day'
      current_day += 1
      feature_days << { backend: [], frontend: [], mobile: [], unassigned: [] }
      puts "put #{story['story_estimate']}h #{story['story_resource']} story into day #{current_day}"
      feature_days.last[story['story_resource'].to_sym] << story
    end
  end

  feature_days.each do |day|
    f.write('<td>')
    %i[backend frontend mobile unassigned].each do |kind|
      f.write(day[kind].collect{|i| i['story_estimate'] }.join('+') + "&nbsp;#{kind}<br/>") if !day[kind].empty?
    end
    f.write('</td>')
  end

  f.write('</tr>')

  global_taken_days << feature_days
  global_taken_days = global_taken_days.compact.flatten
end

# For each Feature, find tasks in sprints, and add to calendar array

# Take all other prioritized Features without Stories
f.write("<tr><th colspan=\"3\">Total</th><th>#{total_duration}</th><th colspan=#{days.count}></th></tr>")
f.write("<tr><td colspan=#{4 + days.count}>Unestimated</td></tr>")

raw_features = ActiveRecord::Base.connection.execute('
  SELECT *
  FROM features
  WHERE id NOT IN (SELECT feature_id FROM stories WHERE feature_id > 0)
  ORDER BY priority ASC, id ASC
')

raw_features.each do |feature|
  f.write('<tr>')

  f.write("<td>#{feature['name']}</td>")
  f.write("<td>#{feature['id']}</td>")
  f.write("<td>#{feature['priority']}</td>")

  f.write('</tr>')
end


f.close
