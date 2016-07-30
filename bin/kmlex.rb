#!/usr/bin/env ruby
require "bundler/setup"

require 'csv'
require "panatrans/kml_extractor"
require 'nokogiri'
require 'open-uri'
require 'pp'
require 'cross/track/distance'

def to_csv(arr, file_path)
  CSV.open(file_path, 'w') do |csv|
    csv << arr[0].keys
    arr.each do |row|
      csv << row.values
    end
  end
end


if ARGV[0].nil?
  puts "  Usage: "
  puts "    kmlex.rb <path_to_file.kml> "
  exit
end

kml_file_path = ARGV[0]
puts "loading #{kml_file_path}"
if !File.exist?(kml_file_path)
  puts 'Error: ' + kml_file_path + ' does not exist'
end
puts "file_exists.."
kml_file = ::Panatrans::KmlExtractor::KmlFile.new(kml_file_path)
puts "loaded file..."
#pp kml_file.route_list
#pp kml_file.stop_list

routes = kml_file.gtfs_routes
puts "Got #{routes.count}routes..."
to_csv(routes,'routes.txt')
puts "Saved file routes.txt"

stops = kml_file.gtfs_stops
puts "Got #{stops.count} stops..."
to_csv(stops,'stops.txt')
puts "Saved file stops.txt"

trips = kml_file.gtfs_trips
puts "Got #{trips.count} trips..."
to_csv(trips,'trips.txt')
puts "Saved file trips.txt"

shapes = kml_file.gtfs_shapes
puts "Got #{shapes.count} shapes..."
to_csv(shapes,'shapes.txt')
puts "Saved file shapes.txt"

#stop_times = kml_file.gtfs_stop_times(10,true)
#puts "Got #{stop_times.count} stop_times..."
#to_csv(stop_times,'stop_times.txt')
#puts "Saved file stop_times.txt"

puts "add required files to feed"
to_csv(kml_file.gtfs_agency, 'agency.txt')
to_csv(kml_file.gtfs_calendar, 'calendar.txt')
