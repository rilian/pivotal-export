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

# Calculate helpers
sprint_days = 5 * ENV['SPRINT_SIZE'].to_i / 40.0
days_count = ActiveRecord::Base.connection.execute('SELECT COUNT(DISTINCT id) FROM days').to_a.first['count'].to_i
sprints = (days_count / sprint_days).ceil.to_i
free_days = 7 - sprint_days
holidays = (sprints * free_days).to_i
real_days_count = days_count + holidays

sprints.times do |i|
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

def is_free_day?(index, free_days)
  (index % 7).to_i >= 7 - free_days
  end

def is_weekend?(index)
  (index % 7).to_i >= 5
end

next_start_of_week_date = date_of_next('Monday')
dates = []
current_date = next_start_of_week_date
real_days_count.times do
  dates << current_date
  current_date = current_date + 1.day
end

dates.each { |day| f.write "<th>#{day.strftime('%d %b')}</th>" }

f.write('</tr>
      <tr>
        <th>Feature</th>
        <th>ID</th>
        <th>Priority</th>
        <th>Estimated Duration</th>')

dates.each { |day| f.write "<td>#{day.strftime('%a')}</td>" }

f.write('</tr>')

# Take prioritized Features, first with stories, then other
raw_features = ActiveRecord::Base.connection.execute('
  (SELECT *
  FROM features
  WHERE id IN (SELECT feature_id FROM stories WHERE feature_id > 0 AND accepted_at IS NULL)
  ORDER BY priority ASC, id ASC)
  UNION ALL
  (SELECT *
  FROM features
  WHERE id NOT IN (SELECT feature_id FROM stories WHERE feature_id > 0 AND accepted_at IS NULL)
  ORDER BY priority ASC, id ASC)
')

raw_features.each do |feature|
  f.write('<tr>')
  f.write("<td>#{feature['name']}</td>")
  f.write("<td>#{feature['id']}</td>")
  f.write("<td>#{feature['priority']}</td>")

  raw_duration = ActiveRecord::Base.connection.execute("
    SELECT SUM(story_estimate) as sum FROM days WHERE feature_id=#{feature['id']}
  ")
  duration = raw_duration.to_a.first['sum'].to_i
  f.write("<td>#{duration}</td>")

  dates.each_with_index do |date, index|
    f.write('<td>')

    if !is_free_day?(index, free_days)
      day_id = (index - (index / 7).to_i * free_days).to_i

      raw_days = ActiveRecord::Base.connection.execute("
        SELECT * FROM days WHERE id='#{day_id}' and feature_id=#{feature['id']}")
      raw_days.each do |day|
        f.write("#{day['story_estimate']} #{ENV["#{day['story_project_id']}_NAME"]}<br/>")
      end

    else
      if !is_weekend?(index)
        f.write('&nbsp;')
      else
        f.write('-')
      end
    end

    f.write('</td>')
  end

  f.write('</tr>')
end

# Draw Planned work
f.write('<tr><td>Planned work</td><td>&nbsp;</td><td>&nbsp;</td>')

raw_duration = ActiveRecord::Base.connection.execute('
  SELECT SUM(story_estimate) as sum FROM days WHERE feature_id IS NULL')
duration = raw_duration.to_a.first['sum'].to_i
f.write("<td>#{duration}</td>")

dates.each_with_index do |date, index|
  f.write('<td>')

  if !is_free_day?(index, free_days)
    day_id = (index - (index / 7).to_i * free_days).to_i

    raw_days = ActiveRecord::Base.connection.execute("
        SELECT * FROM days WHERE id='#{day_id}' and feature_id IS NULL")
    raw_days.each do |day|
      f.write("#{day['story_estimate']} #{ENV["#{day['story_project_id']}_NAME"]}<br/>")
    end

  else
    if !is_weekend?(index)
      f.write('&nbsp;')
    else
      f.write('-')
    end
  end

  f.write('</td>')
end

f.write('</tr>')
f.write('</table></body></html>')
f.close

puts 'Gantt Chart built'
