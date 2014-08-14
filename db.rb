require 'active_record'

ActiveRecord::Base.establish_connection({
  adapter: 'postgresql',
  encoding: 'unicode',
  database: ENV['DATABASE_NAME'],
  host: 'localhost'
})

def get_story_record(json)
  labels = json['labels'].collect{ |l| l['name'] }
  labels << "F#{(1 + rand(@features.count))}" if ENV['RANDOMIZE_LABELS'] == 'true' if @features

  "INSERT INTO \"stories\" (
    id,
    project_id,
    feature_id,
    url,
    kind,
    story_type,
    created_at,
    updated_at,
    accepted_at,
    current_state,
    labels,
    estimate,
    name,
    description,
    requested_by_id,
    owner_ids
  ) VALUES (
    '#{json['id']}',
    #{json['project_id']},
    NULL,
    '#{json['url']}',
    '#{json['kind']}',
    '#{json['story_type']}',
    #{json['created_at']},
    #{json['updated_at']},
    #{json['accepted_at'] || 'NULL'},
    '#{json['current_state']}',
    #{ActiveRecord::Base.connection.quote(labels.join(','))},
    #{json['estimate'] || 0},
    #{ActiveRecord::Base.connection.quote((json['name'] || ''))},
    #{ActiveRecord::Base.connection.quote((json['description'] || ''))},
    #{json['requested_by_id'] || 0},
    '#{(json['owner_ids'] + Array.wrap(json['owned_by_id'])).uniq.join(',')}'
  );"
end
