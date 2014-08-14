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
  ')
end

@stories.each do |story|
  ActiveRecord::Base.connection.execute(get_story_record(story))
end
