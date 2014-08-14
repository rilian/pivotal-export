raw = ActiveRecord::Base.connection.execute("

select features.id as feature_id,
                      features.priority,
                      features.name,
                      stories.id as story_id,
                                    stories.labels,
                                    stories.name

from features
join stories
on (stories.labels like '%F' || features.id) OR
(stories.labels like '%F' || features.id || ',')

order by features.priority ASC
")

f = File.open('tmp/ordered_stories.html', 'w')
f.write('<html><body><table>
<tr>
<th>feature_id</th>
<th>priority</th>
<th>feature name</th>
<th>story id</th>
<th>story labels</th>
<th>story name</th>
</tr>')
raw.values.each do |value|
  f.write(
"<tr>
<td>#{value[0]}</td>
<td>#{value[1]}</td>
<td>#{value[2]}</td>
<td>#{value[3]}</td>
<td>#{value[4]}</td>
<td>#{value[5]}</td>
</tr>")
end

f.write('</table></body></html>')

f.close
