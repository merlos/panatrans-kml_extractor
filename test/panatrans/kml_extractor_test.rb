require 'test_helper'

class Panatrans::KmlExtractorTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Panatrans::KmlExtractor::VERSION
  end

  def setup
    @kml_string = File.open('test/fixtures/test.kml', 'r') { |f| f.read }
    @kml = Nokogiri::XML(open('./test/fixtures/test.kml'))
    @kml_stop_placemark = nil
    @kml_route_placemark = nil
    @kml_stop_folder = nil

    @kml.css('Folder').each do |folder|

    end #kml folder
    @s = ::Panatrans::KmlExtractor::StopPlacemark.new(1, @kml_stop_placemark)
    @r = ::Panatrans::KmlExtractor::RoutePlacemark.new(1, @kml_route_placemark)
  end #setup
end
