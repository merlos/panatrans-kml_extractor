require "panatrans/kml_extractor/version"
require 'nokogiri'
require 'open-uri'
require 'pp'
require 'cross/track/distance'

module Panatrans
  module KmlExtractor

    class LatLon
      attr_reader :lat, :lon
      attr_writer :lat, :lon

      def initialize(lat,lon)
        @lat = lat
        @lon = lon
      end

      def coords
        return {lat: @lat, lon: @lon}
      end

      def coords=(pt)
        @lat = pt[:lat]
        @lon = pt[:lon]
      end
    end

    class StopPlacemark < LatLon
      # additional
      attr_reader :id, :placemark, :name
      attr_writer :id, :placemark, :name


      # id is the stop placemark id
      # point is a hash {lat:, lon:}
      def self.new_from_point(id, point)
        s = self.new(point[:lat], point[:lon])
        s.id = id
        s.name = 'stop_' + id.to_s
        return s
      end

      def self.new_from_kml(id, kml_stop_placemark)
        return nil if kml_stop_placemark.nil?
        name = kml_stop_placemark.css('name').text
        coordinates = kml_stop_placemark.at_css('coordinates').content
        (lon,lat) = coordinates.split(',')
        s = self.new(lat.to_f, lon.to_f)
        s.name = name
        #s.placemark = kml_stop_placemark
        s.id = id
        return s
      end

      def to_gtfs_stop_row
        {
          stop_id: @id.to_s,
          stop_name: @name,
          stop_lat: @lat,
          stop_lon: @lon
        }
      end


      # point = {lat, lon}
      # rectangle = {min_lat, min_lon, max_lat, max_lon}
      # returns true or false
      def is_stop_in_box(rectangle)
        point = self.coords
        #puts point
        return false if rectangle[:min_lat] > point[:lat]
        return false if rectangle[:max_lat] < point[:lat]
        return false if rectangle[:min_lon] > point[:lon]
        return false if rectangle[:max_lon] < point[:lon]
        return true
      end

    end #class

    class StopPlacemarkList < Array

      def add_stop_placemark(id, kml_stop_placemark)
        self << StopPlacemark.new_from_kml(id, kml_stop_placemark)
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
        return false if self.count == 0
        self.any? {|item| item.id == stop_placemark.id}
      end

      # returns the StoPlacemarkList of the stops that are within the
      # box
      #box has the format { min_lat, max_lat, min_lon, max_lon}
      def stops_in_box(box)
        in_box = StopPlacemarkList.new
        self.each do |stop|
          in_box << stop if stop.is_stop_in_box(box)
        end
        in_box
      end
    end

    class ShapePoint
      attr_reader :shape_id, :sequence, :lat, :lon

      def initialize(shape_id, sequence, lat, lon)
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
      # reverse coordinates.
      # reverse = true means that the first point in the list of coordinates
      # of the kml_route_placemark is the last point of the route trip. By
      # default is true because MiBus publishes the KML coordinates on reverse
      # order 
      def initialize(id, kml_route_placemark, reverse = true)
        @id = id
        @placemark = kml_route_placemark
        coordinates_string = @placemark.at_css('coordinates').content
        @sequence = 1

        coords = coordinates_string.split(' ')
        coords = coords.reverse if reverse
        coords.each do |coordinate|
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

    class RoutePlacemarkList < Array

      def add_route_folder(kml_route_folder)
        @id= 1 if !defined? @id
        kml_route_folder.css('Placemark').each do |kml_route_placemark|
          self << RoutePlacemark.new(@id, kml_route_placemark)
          @id = @id + 1
        end
      end
    end # class RoutePlacemarkList


    # Extracts the StopTimes from a RoutePlacemark and a stop_list
    # stop_list is the list of all stops in the map.
    # route is a route with the shape (list of points).
    # usage:
    #  ste = StopTimesExtractor.new(route, stop_list)
    #  ste.run
    #  then
    #     ste.route_stops has a StopPlacemarkList with the route stops ordered
    #     ste.to_gtfs_stop_times returns an array with the stop times rows
    #
    #
    class StopTimesExtractor

      attr_reader :route, :stop_list, :route_stops

      def initialize(route, stop_list)
        @route = route
        @stop_list = stop_list
        @route_stops = nil
      end

      # given two points in (point.lat, point.lon} and a radius (in meters)
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
        radius_lon1 = (radius.to_f / 111194.9) * Math::cos(point1.lat.to_f.to_rad).abs
        radius_lon2 = (radius.to_f / 111194.9) * Math::cos(point2.lat.to_f.to_rad).abs # for small distances probably both radius almost the same...
        #puts radius_lat
        #puts radius_lon1
        #puts radius_lon2
        lats = [point1.lat + radius_lat, point1.lat - radius_lat,
          point2.lat + radius_lat, point2.lat - radius_lat]
          lons = [point1.lon + radius_lon1, point1.lon - radius_lon1,
            point2.lon + radius_lon2, point2.lon - radius_lon2]
            #puts lats
            #puts lons
            {max_lat: lats.max, min_lat: lats.min, max_lon: lons.max, min_lon: lons.min}
          end

          # retuns the bounding box of the point
          # radius in meters
          def point_bounding_box(point,radius)
            self.bounding_box(point, point, radius)
          end


          # point.lat point.lon}
          # rectangle = {min_lat, min_lon, max_lat, max_lon}
          # returns true or false
          def is_point_in_rectangle(point, rectangle)
            return false if rectangle[:min_lat] > point.lat
            return false if rectangle[:max_lat] < point.lat
            return false if rectangle[:min_lon] > point.lon
            return false if rectangle[:max_lon] < point.lon
            return true
          end

          def closest_point(point_arr, point)
            return nil if point_arr.nil?
            return nil if point_arr.count < 1
            min_d = 4000000000.0
            closest = nil
            point_arr.each do |pt|
              d = Haversine.distance([pt.lat,pt.lon], [point.lat,point.lon])
              if d.to_m < min_d then
                min_d = d.to_m
                closest = pt
              end
            end
            return closest
          end

          # gets the colosest point to a segment from an array of points
          # segment_start and segment_end = LatLon
          # point_arr is an array of LatLon
          def closest_point_to_segment_at_right(point_arr, segment_start, segment_end)
            return nil if point_arr.count < 1
            min_distance = 400000000.0 #arbitrarily large distance in meters
            closest_point = nil
            point_arr.each do |point|
              d = Cross::Track::Distance.cross_track_distance(segment_start.coords,segment_end.coords,point.coords)
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
            @route_stops = nil
            @route_stops = StopPlacemarkList.new
            segment_start = nil
            segment_end = nil
            #pp route.shape
            #pp stop_list
            #pp route
            route.shape.each do |shape_point|
              #pp shape_point.inspect
              #pp route_stops
              #first point
              if segment_start.nil? then
                segment_start = shape_point
                box = self.point_bounding_box(shape_point, radius)
                stops_in_box = @stop_list.stops_in_box(box)
                first_stop = self.closest_point(stops_in_box, segment_start)
                @route_stops << first_stop if !first_stop.nil?
              else
                segment_start = segment_end if !segment_end.nil?
                segment_end = shape_point
                box = self.bounding_box(segment_start, segment_end, radius)
                stops_in_box = @stop_list.stops_in_box(box)
                next if stops_in_box.empty?
                new_stop = self.closest_point_to_segment_at_right(stops_in_box, segment_start, segment_end)
                next if new_stop.nil?
                @route_stops << new_stop if !@route_stops.includes_stop_placemark(new_stop)
              end
            end #shape_point
            # add final stop if not added yet
            box = self.point_bounding_box(@route.shape.last, radius)
            stops_in_box = @stop_list.stops_in_box(box)
            last_stop = self.closest_point(stops_in_box, @route.shape.last)
            if !last_stop.nil?
              @route_stops << last_stop if !@route_stops.includes_stop_placemark(last_stop)
            end
          end

          def to_gtfs_stop_times_rows
            return nil if @route_stops.nil?
            stop_times = []
            sequence = 0
            @route_stops.each do |stop|
              sequence = sequence + 1
              stop_times << {
                trip_id: 'trip_' + @route.id.to_s,
                arrival_time: '',
                departure_time: '',
                stop_id: stop.id,
                stop_sequence: sequence
              }
            end #@route_stops
            return stop_times
          end
        end # class





        class KmlFile
          attr_reader :doc, :stop_list, :route_list
          def initialize(kml_file_path)
            @file_path = kml_file_path
            @doc = Nokogiri::XML(open(kml_file_path))
            @stop_list = ::Panatrans::KmlExtractor::StopPlacemarkList.new
            @route_list = ::Panatrans::KmlExtractor::RoutePlacemarkList.new
            @doc.css('Folder').each do |folder|
              if folder.at_css('name').content == 'Rutas_por_parada' then
               @stop_list.add_stop_folder(folder)
              end
              if folder.at_css('name').content == 'RUTAS_METROBUS_2016' then
                @route_list.add_route_folder(folder)
              end
            end #run_kml folder
          end # def

          def gtfs_agency
            [{
              agency_id: 'mibus',
              agency_name: 'Mibus',
              agency_url: 'http://www.panatrans.org',
              agency_timezone: 'America/Panama',
              agency_lang: 'es'
            }]
          end
          def gtfs_calendar
            [{
              service_id: 'mibus',
              monday: 1,
              tuesday: 1,
              wednesday: 1,
              thursday: 1,
              friday: 1,
              saturday: 1,
              sunday: 1,
              start_date: 20160729,
              end_date: 20500729
            }]
          end

          def gtfs_stops
            arr = []
            @stop_list.each do |stop|
              arr << stop.to_gtfs_stop_row
            end
            return arr
          end

          def gtfs_routes
            arr = []
            @route_list.each do |item|
              arr << item.to_gtfs_route_row
            end
            return arr
          end

          def gtfs_trips
            arr = []
            @route_list.each do |item|
              arr << item.to_gtfs_trip_row
            end
            return arr
          end
          def gtfs_shapes
            arr = []
            @route_list.each do |item|
              arr.concat item.to_gtfs_shape_rows
            end
            return arr
          end

          def gtfs_stop_times(radius, verbose = false)
            arr = []
            @route_list.each do |item|
              stop_times = StopTimesExtractor.new(item, @stop_list)
              stop_times.run(radius)
              puts "added #{stop_times.route_stops.count} stop_times for route #{item.name} · #{item.id}" if verbose
              arr.concat stop_times.to_gtfs_stop_times_rows
            end
            return arr
          end
        end
      end
    end
