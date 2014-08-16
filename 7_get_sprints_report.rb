require 'dotenv'
Dotenv.load
require 'byebug'

require_relative 'db'

puts 'Produce Days report'

raw = ActiveRecord::Base.connection.execute('
  SELECT
    id,
    feature_name,
    story_name,
    story_estimate,
    story_project_id
  FROM days
  ORDER BY id ASC
')

f = File.open('tmp/days.html', 'w')
f.write('
<html>
  <head>
    <title>Days</title>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
  </head>
  <body>
    <table border="1">
      <tr>
        <th>Day #</th>
        <th>Feature</th>
        <th>Story</th>
        <th>Story Estimate</th>
        <th>Story Project</th>
      </tr>')

sprints = []
sprint_days = 5 * ENV['SPRINT_SIZE'].to_i / 40.0
raw.values.each do |value|
  if value[0].to_i % sprint_days == 0 && sprints[value[0].to_i / sprint_days].nil?
    sprints[value[0].to_i / sprint_days] = true
    f.write("
      <tr><th colspan=\"5\">Sprint #{(value[0].to_i / sprint_days).to_i + 1}</th></tr>")
  end

  f.write("
      <tr>
        <td>#{value[0].to_i + 1}</td>
        <td>#{value[1].strip}</td>
        <td>#{value[2].strip}</td>
        <td>#{value[3].strip}</td>
        <td>#{ENV["#{value[4]}_NAME"]}</td>
      </tr>")
end

f.write('
    </table>
  </body>
</html>')

f.close
