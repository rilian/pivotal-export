require 'dotenv'
Dotenv.load
require 'byebug'
require 'date'

require_relative 'db'

# Export
puts 'Produce Teamgantt CSV'

f = File.open('tmp/new_teamgantt.csv', 'w')

raw_features = ActiveRecord::Base.connection.execute('
  SELECT *
  FROM features
  ORDER BY priority ASC, id ASC')

raw_features.each do |feature|
  f.write("\"[#{feature['priority']}] #{feature['name']}\",\"#{Time.now.strftime('%d %b, %Y')}\",\"#{Time.now.strftime('%d %b, %Y')}\"\n")
end

f.close

puts 'Teamgantt CSV built'

