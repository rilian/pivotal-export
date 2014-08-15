require 'dotenv'
require 'byebug'
Dotenv.load

puts 'Running Pivotal Parser'

require_relative '1_import_features'
require_relative '2_load_stories'
require_relative '3_import_stories'
require_relative '4_set_feature_id_to_story'
require_relative '5_get_stories_report'
require_relative '6_import_sprints'
require_relative '7_get_sprints_report'
require_relative '8_get_gantt_report'

puts 'Done'
