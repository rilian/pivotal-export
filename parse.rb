require 'fileutils'
require 'dotenv'

Dotenv.load

puts 'Running Pivotal Parser'

PROJECT_IDS = ENV['PROJECT_IDS'].split(',')
PIVOTAL_API_KEY = ENV['PIVOTAL_API_KEY']
PIVOTAL_API_URI = 'https://www.pivotaltracker.com/services/v5'

Dir.mkdir('tmp') unless Dir.exists?('tmp')
FileUtils.rm_rf('tmp/.')

PROJECT_IDS.each do |project_id|
  `curl -X GET -H "X-TrackerToken: #{PIVOTAL_API_KEY}" "#{PIVOTAL_API_URI}/projects/#{project_id}/stories" > ./tmp/stories_#{project_id}.json`
end

