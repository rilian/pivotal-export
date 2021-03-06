require 'dotenv'
Dotenv.load

require_relative 'db'

puts 'Produce prioritized Stories report'

raw = ActiveRecord::Base.connection.execute('
  SELECT
    features.id        AS feature_id,
    features.name      AS feature_name,
    features.priority,
    stories.id         AS story_id,
    stories.name       AS story_name,
    stories.project_id AS project_id

  FROM stories

  LEFT OUTER JOIN features ON stories.feature_id = features.id

  WHERE stories.accepted_at IS NULL

  ORDER BY features.priority ASC, features.id ASC, stories.id ASC
')

f = File.open('tmp/ordered_stories.html', 'w')
f.write('
<html>
  <head>
    <title>Stories ordered</title>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
  </head>
  <body>
    <table border="1">
      <tr>
        <th>feature_id</th>
        <th>feature_name</th>
        <th>priority</th>
        <th>story_id</th>
        <th>story_name</th>
        <th>project</th>
      </tr>')

raw.values.each do |value|
  f.write("
      <tr>
        <td>#{(value[0] || '').strip}</td>
        <td>#{(value[1] || '').strip}</td>
        <td>#{(value[2] || '').strip}</td>
        <td>#{(value[3] || '').strip}</td>
        <td>#{(value[4] || '').strip}</td>
        <td>#{(value[5] || '').strip}</td>
      </tr>")
end

f.write('
    </table>
  </body>
</html>')

f.close
