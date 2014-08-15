require 'dotenv'
Dotenv.load
require 'byebug'

require_relative 'db'

puts 'Produce Gantt Chart report'

# Take prioritized Features that have Stories that split to Sprints
# For each Feature, find tasks in sprints, and add to calendar array
# Take all other prioritized Features without Stories

