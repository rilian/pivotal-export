raw = ActiveRecord::Base.connection.execute("
  select distinct
    features.id        as feature_id,
    features.name      as feature_name,
    features.priority,
    stories.id         as story_id,
    stories.name       as story_name

  from features

  join stories
    on (stories.labels like '%F' || features.id) OR
       (stories.labels like '%F' || features.id || ',')

  order by features.priority ASC, features.id ASC, stories.id ASC
")

f = File.open('tmp/ordered_stories.html', 'w')
f.write('
<html>
  <head>
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
      </tr>')

raw.values.each do |value|
  f.write("
      <tr>
        <td>#{value[0]}</td>
        <td>#{value[1]}</td>
        <td>#{value[2]}</td>
        <td>#{value[3]}</td>
        <td>#{value[4]}</td>
      </tr>")
end

f.write('
    </table>
  </body>
</html>')

f.close
