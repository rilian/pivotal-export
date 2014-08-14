require 'dotenv'
require 'byebug'

Dotenv.load

puts 'Running Pivotal Parser'

require_relative 'db'

require_relative '1_import_features'
require_relative '2_load_stories'
require_relative '3_import_stories'
require_relative '4_set_feature_id_to_story'
require_relative '5_get_ordered_stories'

puts 'Done'
