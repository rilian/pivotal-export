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
        <th>Date &rarr;</th>')

raw_sprints_count = ActiveRecord::Base.connection.execute('SELECT COUNT(DISTINCT id) FROM sprints')
sprints_count = raw_sprints_count.to_a.first['count'].to_i

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

days.each { |day| f.write "<th>#{day}</th>" }

f.write('</tr>
      <tr>
        <th>Feature</th>
        <th>ID</th>
        <th>Priority</th>
        <th>Estimated Duration</th>')

days.each { |day| f.write "<th>#{day.strftime('%a')}</th>" }

f.write('</tr>')

f.close

# Take prioritized Features that have Stories that split to Sprints
raw_features = ActiveRecord::Base.connection.execute('
  SELECT *
  FROM features
  WHERE id IN (SELECT feature_id FROM stories)
  ORDER BY priority ASC, id ASC
')

raw_features.each do |feature|

end

# For each Feature, find tasks in sprints, and add to calendar array
# Take all other prioritized Features without Stories

