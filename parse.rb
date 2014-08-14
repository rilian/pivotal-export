require 'dotenv'
require 'byebug'

Dotenv.load

puts 'Running Pivotal Parser'

require_relative 'db'

require_relative 'import_features'

require_relative 'load_stories'
require_relative 'import_stories'

require_relative 'get_ordered_stories'

puts 'Done'
