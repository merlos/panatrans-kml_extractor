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
      if folder.at_css('name').content == 'Rutas_por_parada' then
        @kml_stop_folder = folder
        folder.css('Placemark').each do |placemark|
          @kml_stop_placemark = placemark if placemark.at_css('name').content == 'TestStop'
        end
      end
      if folder.at_css('name').content == 'RUTAS_METROBUS_2016' then
        folder.css('Placemark').each do |placemark|
          @kml_route_placemark = placemark if placemark.at_css('name').content == 'TestRoute'
        end
      end
    end #kml folder
    @s = ::Panatrans::KmlExtractor::StopPlacemark.new(1, @kml_stop_placemark)
    @r = ::Panatrans::KmlExtractor::RoutePlacemark.new(1, @kml_route_placemark)
  end #setup


    def test_kml_stop_placemark_was_set_on_setup
      assert_equal 'TestStop', @kml_stop_placemark.at_css('name').content
    end

    def test_kml_route_placemark_was_set_on_setup
      assert_equal 'TestRoute', @kml_route_placemark.at_css('name').content
    end

    # StopPlacemark tests
    def test_stop_placemark_constructor
      s = ::Panatrans::KmlExtractor::StopPlacemark.new(1, @kml_stop_placemark)
      assert_equal 'TestStop', s.name
    end

    def test_route_placemark_constructor
      r = ::Panatrans::KmlExtractor::RoutePlacemark.new(1, @kml_route_placemark)
      assert_equal 'TestRoute', r.name
    end

    def test_stop_placemark_to_gtfs_stop_row
      row = @s.to_gtfs_stop_row
      assert_equal "1", row[:stop_id]
      assert_equal "TestStop", row[:stop_name]
      assert_equal(-80.000001, row[:stop_lon])
      assert_equal 9.000000, row[:stop_lat]
    end



end
