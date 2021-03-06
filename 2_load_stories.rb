require 'dotenv'
Dotenv.load
require 'fileutils'
require 'json'
require 'byebug'
require_relative 'db'

PROJECT_IDS = ENV['PROJECT_IDS'].split(',')
PIVOTAL_API_KEY = ENV['PIVOTAL_API_KEY']
PIVOTAL_API_URI = 'https://www.pivotaltracker.com/services/v5'

Dir.mkdir('tmp') unless Dir.exists?('tmp')
FileUtils.rm_rf('tmp/.')

puts 'Load stories from Pivotal'

@stories = []

PROJECT_IDS.each do |project_id|
  offset = 0
  limit = ENV['PIVOTAL_CHUNK_SIZE']
  received = 0
  begin
    path = "#{PIVOTAL_API_URI}/projects/#{project_id}/stories?limit=#{limit}&offset=#{offset}&date_format=millis"
    file = "./tmp/stories_#{project_id}_#{limit}_#{offset}.json"
    `curl -X GET -H "X-TrackerToken: #{PIVOTAL_API_KEY}" "#{path}" > "#{file}"`
    stories_chunk = JSON.parse(File.read(file))
    @stories << stories_chunk
    received = stories_chunk.count
    puts "\nLoaded #{received} stories and saved to #{file}"
    offset += received
  end while received > 0
end

@stories.flatten!

puts "Total #{@stories.count} stories loaded from Pivotal"
