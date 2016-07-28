require "panatrans/kml_extractor/version"
require 'nokogiri'
require 'open-uri'
require 'pp'
require 'cross/track/distance'

module Panatrans
  module KmlExtractor


    class StopPlacemark
      attr_reader :id, :placemark, :name, :lat, :lon

      def initialize(id, kml_stop_placemark)
        @placemark = kml_stop_placemark
        @id = id
        @name = @placemark.css('name').text
        coordinates = @placemark.at_css('coordinates').content
        (lon,lat) = coordinates.split(',')
        @lat = lat.to_f
        @lon = lon.to_f
      end

      def to_gtfs_stop_row
        {
          stop_id: @id.to_s,
          stop_name: @name,
          stop_lat: @lat,
          stop_lon: @lon
        }
      end

      def coords
        {lat: @lat, lon: @lon}
      end

    end #class

    class StopPlacemarkList < Array

      def add_stop_placemark(id, kml_stop_placemark)
        self << StopPlacemark.new(id, kml_stop_placemark)
      end

      def add_stop_folder(kml_stop_folder)
        @id= 1 if !defined? @id
        kml_stop_folder.css('Placemark').each do |kml_stop_placemark|
          self.add_stop_placemark(@id, kml_stop_placemark)
          @id = @id + 1
        end
      end

      # search for an stop within the list. Compares by id
      # argument is StopPlacemark
      def includes_stop_placemark (stop_placemark)
        self.any? {|item| item.id == stop_placemark.id}
      end
    end


    class ShapePoint
      attr_reader :shape_id, :sequence, :lat, :lon

      def initialize(shape_id,sequence,lat,lon)
        @shape_id = shape_id
        @sequence = sequence
        @lat = lat
        @lon = lon
      end

      def coords
        {lat: @lat, lon: @lon}
      end

      def to_gtfs_shape_row
        {shape_id: @shape_id,
          shape_pt_lat: @lat,
          shape_pt_lon: @lon,
          shape_pt_sequence: @sequence
        }
      end
    end

    #
    #
    class ShapeList < Array
      #
      # id: route_id
      # coordinates
      def initialize(id, kml_route_placemark)
        @id = id
        @placemark = kml_route_placemark
        coordinates = @placemark.at_css('coordinates').content
        @sequence = 1
        coordinates.split(' ').each do |coordinate|
          (lon,lat) = coordinate.split(',')
          lat = lat.to_f
          lon = lon.to_f
          self << ShapePoint.new(self.shape_id, @sequence,lat, lon)
          @sequence = @sequence + 1
        end # coordinates each
      end

      def shape_id
        'shape_' + @id.to_s
      end

      def to_gtfs_shape_rows
        shape = []
        self.each do |shape_point|
          shape.push(shape_point.to_gtfs_shape_row)
        end
        return shape
      end
    end



    class RoutePlacemark

      attr_reader :id, :placemark, :name, :desc, :shape

      def initialize(id, kml_route_placemark)
        @placemark = kml_route_placemark
        @id = id
        @name = @placemark.css('name').text
        @desc = @placemark.css('description').text
        @shape = ShapeList.new(id, @placemark)
      end

      def to_gtfs_route_row
        {
          route_id: @id.to_s,
          agency_id: 'mibus',
          route_short_name: @name,
          route_long_name: @name,
          route_desc: @desc,
          route_type: 3
        }
      end

      def name=(value)
        @name = value
      end

      # {
      # route_id: id
      # service_id: 'mibus'
      # trip_id: trip_+ id
      # trip_headsign: 2 latest of parts of the route name
      # trip_direction_id: 0
      # shape_id: shape_ + id
      # }
      def to_gtfs_trip_row
        route_parts = @name.split('-')
        headsign = @name
        if route_parts.count >= 2 then
          headsign = route_parts[-2] + '-' + route_parts[-1]
        end
        {
          route_id: @id.to_s,
          service_id: 'mibus',
          trip_id: 'trip_' + @id.to_s,
          trip_headsign: headsign,
          trip_direction_id: 0,
          shape_id: 'shape_' + @id.to_s
        }
      end

      def to_gtfs_shape_rows
        @shape.to_gtfs_shape_rows
      end

    end # RoutePlacemark


    class StopTimesExtractor

      attr_reader :route, :stop_list

      def initialize(route, stop_list)
        @route = route
        @stop_list = stop_list
      end

      # given two points in {lat, lon} and a radius (in meters)
      # it returns a box with contains both points and has a padding of the radius
      # size.
      # +-----------+
      # |  x        |
      # |           |
      # |         x |
      # +-----------+
      #
      def bounding_box(point1, point2, radius)
        #puts point1
        #puts point2
        radius_lat = radius.to_f / 111194.9
        radius_lon1 = (radius.to_f / 111194.9) * Math::cos(point1[:lat].to_f.to_rad).abs
        radius_lon2 = (radius.to_f / 111194.9) * Math::cos(point2[:lat].to_f.to_rad).abs # for small distances probably both radius almost the same...
        #puts radius_lat
        #puts radius_lon1
        #puts radius_lon2
        lats = [point1[:lat] + radius_lat, point1[:lat] - radius_lat,
        point2[:lat] + radius_lat, point2[:lat] - radius_lat]
        lons = [point1[:lon] + radius_lon1, point1[:lon] - radius_lon1,
        point2[:lon] + radius_lon2, point2[:lon] - radius_lon2]
        #puts lats
        #puts lons
        {max_lat: lats.max, min_lat: lats.min, max_lon: lons.max, min_lon: lons.min}
      end

      # retuns the bounding box of the point
      # radius in meters
      def point_bounding_box(point,radius)
        self.bounding_box(point, point, radius)
      end


      # point = {lat, lon}
      # rectangle = {min_lat, min_lon, max_lat, max_lon}
      # returns true or false
      def is_point_in_rectangle(point, rectangle)
        if rectangle[:min_lat] > point[:lat] then
          return false
        end
        if rectangle[:max_lat] < point[:lat] then
          return false
        end
        if rectangle[:min_lon] > point[:lon] then
          return false
        end
        if rectangle[:max_lon] < point[:lon] then
          return false
        end
        return true
      end

      def closest_point(point_arr, point)
        return nil if point_arr.nil?
        return nil if point_arr.count < 1
        min_d = 4000000000.0
        closest = nil
        point_arr.each do |pt|
          d = Haversine.distance([pt[:lat],pt[:lon]], [point[:lat],point[:lon]])
          if d.to_m < min_d then
            min_d = d.to_m
            closest = pt
          end
        end
        return closest
      end

      # gets the colosest point to a segment from an array of points
      # segment_start and segment_end = {lat:, lon:}
      # pointArr is an array with points with lat, and lon
      def closest_point_to_segment_at_right(point_arr, segment_start, segment_end)
        return nil if point_arr.count < 1
        min_distance = 400000000.0 #arbitrarily large distance in meters
        closest_point = nil
        point_arr.each do |point|
          d = Cross::Track::Distance.cross_track_distance(segment_start,segment_end,point)
          if (d>0) && (d<min_distance) then
            closest_point = point
            min_distance = d
          end
        end #each
        return closest_point
      end
      #
      # Extracts the StopTimes from the route with a radius in meters
      def run(radius)
        segment_start = nil
       segment_end = nil
       route.shape.each do |shape_point|
         #pp shape_point.inspect
         #first point
         if segment_start.nil? then
           segment_start = shape_point
           box = self.point_bounding_box(shape_point.coords, radius)
           #self.closest_point_to_segment_at_right()
         else
           segment_start = segment_end
           segment_end = shape_point
         end
       end #shape_point

      end
    end # class
  end
end
