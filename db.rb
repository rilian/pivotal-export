require 'active_record'

ActiveRecord::Base.establish_connection({
  adapter: 'postgresql',
  encoding: 'unicode',
  database: ENV['DATABASE_NAME'],
  host: 'localhost'
})

if ENV['DROP_TABLES'] == 'true'
  ActiveRecord::Base.connection.execute('
    DROP TABLE IF EXISTS "stories";

    CREATE TABLE "stories" (
      "id" varchar,
      "project_id" int8,
      "url" varchar,
      "kind" varchar,
      "story_type" varchar,
      "created_at" int8,
      "updated_at" int8,
      "accepted_at" int8 NULL,
      "current_state" varchar,
      "labels" varchar,
      "estimate" int8,
      "name" text,
      "description" text,
      "requested_by_id" int8,
      "owner_ids" varchar
    )
    WITH (OIDS=FALSE);

    DROP TABLE IF EXISTS "features";

    CREATE TABLE "features" (
      "id" varchar,
      "priority" int8,
      "name" varchar
    )
    WITH (OIDS=FALSE);
  ')
end

def get_story_record(json)
  labels = json['labels'].collect{ |l| l['name'] }
  labels << "F#{rand(@features.count)}" if ENV['RANDOMIZE_LABELS'] == 'true'

  "INSERT INTO \"stories\" (
    id,
    project_id,
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
