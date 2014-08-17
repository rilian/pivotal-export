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
    <table border="1">')

# Calculate helpers
sprint_days = 5 * ENV['SPRINT_SIZE'].to_i / 40.0
days_count = ActiveRecord::Base.connection.execute('SELECT COUNT(DISTINCT id) FROM days').to_a.first['count'].to_i
sprints = (days_count / sprint_days).ceil.to_i
free_days = 7 - sprint_days
holidays = (sprints * free_days).to_i
real_days_count = (((days_count + holidays) / 7.0).ceil * 7).to_i

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
csv_data = []
current_date = next_start_of_week_date
real_days_count.times do
  dates << current_date
  current_date = current_date + 1.day
end

def draw_dates(f, dates, sprints)
  f.write('<tr><th></th><th></th><th></th><th></th><th></th><th>Sprint&nbsp;&rarr;</th>')
  sprints.times do |i|
    f.write "<th colspan=\"7\">#{i + 1}</th>"
  end
  f.write('</tr>')

  f.write('<tr><th></th><th></th><th></th><th></th><th></th><th>Date&nbsp;&rarr;</th>')
  dates.each { |day| f.write "<th>#{day.strftime('%d&nbsp;%b')}</th>" }
  f.write('</tr>')

  f.write('<tr><th>Feature</th><th>ID</th><th>Priority</th><th>Start</th><th>End</th><th>Duration</th>')
  dates.each { |day| f.write "<td>#{day.strftime('%a')}</td>" }
  f.write('</tr>')
end

draw_dates(f, dates, sprints)

# Take prioritized Features, first with stories, then other
if ENV['ORDER_BY_PRIORITY'] == 'true'
  raw_features = ActiveRecord::Base.connection.execute('
    (SELECT *
    FROM features
    WHERE id IN (SELECT feature_id FROM stories WHERE feature_id > 0 AND accepted_at IS NULL)
    ORDER BY priority ASC, id ASC)
    UNION ALL
    (SELECT *
    FROM features
    WHERE id NOT IN (SELECT feature_id FROM stories WHERE feature_id > 0 AND accepted_at IS NULL)
    ORDER BY priority ASC, id ASC)')
else
  raw_features = ActiveRecord::Base.connection.execute('
    SELECT *
    FROM features
    ORDER BY id ASC')
end

raw_features.each do |feature|
  f.write('<tr>')

  f.write("<td>#{feature['name']}</td>")
  csv_data << { group_name: feature['name'].strip }
  f.write("<td>#{feature['id']}</td>")
  f.write("<td>#{feature['priority']}</td>")

  raw_start_day = ActiveRecord::Base.connection.execute("
    SELECT min(id) FROM days WHERE feature_id=#{feature['id']}")
  start_day_id = raw_start_day.to_a.first['min'].to_i
  date_id = (start_day_id + (start_day_id / (7 - free_days)).to_i * free_days).to_i
  f.write("<td>#{dates[date_id].strftime('%d&nbsp;%b')}</td>")
  csv_data.last[:start_date] = dates[date_id].strftime('%d %b, %Y')

  raw_end_day = ActiveRecord::Base.connection.execute("
    SELECT max(id) FROM days WHERE feature_id=#{feature['id']}")
  end_day_id = raw_end_day.to_a.first['max'].to_i
  date_id = (end_day_id + (end_day_id / (7 - free_days)).to_i * free_days).to_i
  f.write("<td>#{dates[date_id].strftime('%d&nbsp;%b')}</td>")
  csv_data.last[:end_date] = dates[date_id].strftime('%d %b, %Y')

  raw_duration = ActiveRecord::Base.connection.execute("
    SELECT SUM(story_estimate) as sum FROM days WHERE feature_id=#{feature['id']}
  ")
  duration = raw_duration.to_a.first['sum'].to_i
  f.write("<td>#{duration}</td>")

  dates.each_with_index do |date, index|
    if !is_free_day?(index, free_days)
      day_id = (index - (index / 7).to_i * free_days).to_i

      raw_days = ActiveRecord::Base.connection.execute("
        SELECT sum(story_estimate) as story_estimate, story_project_id
        FROM days
        WHERE id='#{day_id}' and feature_id=#{feature['id']}
        GROUP BY story_project_id
      ")

      f.write('<td>')
      raw_days.each do |day|
        f.write("#{day['story_estimate']}h&nbsp;#{ENV["#{day['story_project_id']}_NAME"]}<br/>")
      end
      f.write('</td>')
    else
      if !is_weekend?(index)
        f.write('<td>&nbsp;</td>')
      else
        f.write('<td bgcolor="lightgrey">&nbsp;</td>')
      end
    end
  end

  f.write('</tr>')
end

# Draw Planned work
f.write('<tr><td>Planned work</td><td>&nbsp;</td><td>&nbsp;</td>')

raw_start_day = ActiveRecord::Base.connection.execute('
    SELECT min(id) FROM days WHERE feature_id IS NULL')
start_day_id = raw_start_day.to_a.first['min'].to_i
date_id = (start_day_id + (start_day_id / (7 - free_days)).to_i * free_days).to_i
f.write("<td>#{dates[date_id].strftime('%d&nbsp;%b')}</td>")

raw_end_day = ActiveRecord::Base.connection.execute('
    SELECT max(id) FROM days WHERE feature_id IS NULL')
end_day_id = raw_end_day.to_a.first['max'].to_i
date_id = (end_day_id + (end_day_id / (7 - free_days)).to_i * free_days).to_i
f.write("<td>#{dates[date_id].strftime('%d&nbsp;%b')}</td>")

raw_duration = ActiveRecord::Base.connection.execute('
  SELECT SUM(story_estimate) as sum FROM days WHERE feature_id IS NULL')
duration = raw_duration.to_a.first['sum'].to_i
f.write("<td>#{duration}</td>")

dates.each_with_index do |date, index|
  if !is_free_day?(index, free_days)
    day_id = (index - (index / 7).to_i * free_days).to_i

    raw_days = ActiveRecord::Base.connection.execute("
        SELECT * FROM days WHERE id='#{day_id}' and feature_id IS NULL")

    f.write('<td>')
    raw_days.each do |day|
      f.write("#{day['story_estimate']}h&nbsp;#{ENV["#{day['story_project_id']}_NAME"]}<br/>")
    end
    f.write('</td>')
  else
    if !is_weekend?(index)
      f.write('<td>&nbsp;</td>')
    else
      f.write('<td bgcolor="lightgrey">&nbsp;</td>')
    end
  end
end

f.write('</tr>')

draw_dates(f, dates, sprints)

f.write('</table></body></html>')
f.close

puts 'Gantt Chart built'

puts 'Produce Teamgantt CSV'
f = File.open('tmp/teamgantt.csv', 'w')
csv_data.each do |data|
  f.write("\"#{data[:group_name]}\",\"#{data[:start_date]}\",\"#{data[:end_date]}\"\n")
end
f.close
puts 'Teamgantt CSV built'

