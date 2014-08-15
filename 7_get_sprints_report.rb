require 'dotenv'
Dotenv.load
require 'byebug'

require_relative 'db'

puts 'Produce Sprints report'

raw = ActiveRecord::Base.connection.execute('
  SELECT
    id,
    story_name,
    story_estimate,
    story_resource
  FROM sprints
  ORDER BY id ASC
')

f = File.open('tmp/sprints.html', 'w')
f.write('
<html>
  <head>
    <title>Sprints</title>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
  </head>
  <body>
    <table border="1">
      <tr>
        <th>Sprint #</th>
        <th>Story Name</th>
        <th>Story Estimate</th>
        <th>Story Resource</th>
      </tr>')

raw.values.each do |value|
  f.write("
      <tr>
        <td>#{value[0].strip}</td>
        <td>#{value[1].strip}</td>
        <td>#{value[2].strip}</td>
        <td>#{value[3].strip}</td>
      </tr>")
end

f.write('
    </table>
  </body>
</html>')

f.close
