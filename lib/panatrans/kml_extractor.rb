require "panatrans/kml_extractor/version"

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


  end
end
