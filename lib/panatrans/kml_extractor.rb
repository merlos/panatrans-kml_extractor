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




  end
end
