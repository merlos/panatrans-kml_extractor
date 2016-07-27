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


      # StopPlacemarkList tests
      def test_stop_placemark_list_add_stop_placemark
        sl = ::Panatrans::KmlExtractor::StopPlacemarkList.new
        sl.add_stop_placemark(1, @kml_stop_placemark)
        assert_equal 1, sl.count
        assert_equal 1, sl[0].id
        assert_equal 'TestStop', sl[0].name
      end

      def test_stop_placemark_list_add_folder
        sl = ::Panatrans::KmlExtractor::StopPlacemarkList.new
        sl.add_stop_folder(@kml_stop_folder)
        assert_equal 4, sl.count
      end

      def test_stop_placemark_includes_stop_placemark
        sl = ::Panatrans::KmlExtractor::StopPlacemarkList.new
        sl.add_stop_folder(@kml_stop_folder)
        assert_equal 4, sl.count
        assert sl.includes_stop_placemark(@s)
      end


      # Coodinates tests
      def test_shape_point_constructor
        pt = ::Panatrans::KmlExtractor::ShapePoint.new('shape_1',1,8.1,9.1)
        assert_equal 'shape_1', pt.shape_id
        assert_equal 1, pt.sequence
        assert_equal 8.1, pt.lat
        assert_equal 9.1, pt.lon
      end

      def test_shape_point_coords
        pt = ::Panatrans::KmlExtractor::ShapePoint.new('shape_1',1,8.1,9.1)
        c = pt.coords
        assert_equal 8.1, c[:lat]
        assert_equal 9.1, c[:lon]
      end

      def test_shape_point_to_gtfs_shape_row
        pt = ::Panatrans::KmlExtractor::ShapePoint.new('shape_1',1,8.1,9.1)
        row = pt.to_gtfs_shape_row
        assert_equal 'shape_1', row[:shape_id]
        assert_equal 1, row[:shape_pt_sequence]
        assert_equal 8.1, row[:shape_pt_lat]
        assert_equal 9.1, row[:shape_pt_lon]
      end

      # RoutePlacemark tests
      def test_route_placemark_to_gtfs_route_row
        row = @r.to_gtfs_route_row
        assert_equal "1", row[:route_id]
        assert_equal "mibus", row[:agency_id]
        assert_equal "TestRoute", row[:route_short_name]
        assert_equal "TestRoute", row[:route_long_name]
        assert_equal "This is the description that appears in the kml", row[:route_desc]
        assert_equal 3,row[:route_type]
      end

      def test_route_placemark_to_gtfs_trip_row
        row = @r.to_gtfs_trip_row
        assert_equal '1',row[:route_id]
        assert_equal 'mibus',row[:service_id]
        assert_equal 'trip_1',row[:trip_id]
        assert_equal 'TestRoute',row[:trip_headsign]
        assert_equal 0,row[:trip_direction_id]
        assert_equal 'shape_1', row[:shape_id]
      end

      def test_route_placemark_to_gtfs_trip_row_headsign_split
        @r.name = 'A-B-C'
        row = @r.to_gtfs_trip_row
        assert_equal 'B-C',row[:trip_headsign]
      end


      def test_route_placemark_to_shape_rows
        rows = @r.to_gtfs_shape_rows
        #pp rows
        assert_equal 3, rows.count
        row = rows[1];
        # check a shape_row
        assert_equal 'shape_1', row[:shape_id]
        assert_equal 10.2, row[:shape_pt_lon]
        assert_equal 11.2, row[:shape_pt_lat]
        assert_equal 2, row[:shape_pt_sequence]
      end


      #StopTimesExtractor
      def test_bounding_box
        radius = 111194.9 # meters  = 1 degree in latitude.
        p0 = {lat: 0.0, lon: 0.0} # +/-1 deg in lat, +/-1 in lon
        p1 = {lat: 60.0, lon: 1.0} # 1 deg in lat, +/- 0.5 (cos(60)) in lon
        ste = ::Panatrans::KmlExtractor::StopTimesExtractor.new(nil,nil)
        box = ste.bounding_box(p0,p1,radius)
        #puts box
        assert_equal 61.0, box[:max_lat]
        assert_equal(-1.0, box[:min_lat])
        assert_equal 1.5, box[:max_lon]
        assert_equal(-1.0, box[:min_lon])
      end

      def test_is_point_in_rectangle
        ste = ::Panatrans::KmlExtractor::StopTimesExtractor.new(nil,nil)
        box = {min_lat: -2, max_lat: 2, min_lon: -2, max_lon: 2}
        # points inside
        p_in1 = {lat: -1.0, lon: -1.0}
        p_in2 = {lat: 1.0, lon: 1.0 }

        # points outside
        p_out1 = {lat: -3.0, lon: 1.0 }
        p_out2 = {lat: 3.0, lon: 1.0 }
        p_out3 = {lat: 1.0, lon: -3.0 }
        p_out4 = {lat: 1.0, lon: 3.0 }

        assert ste.is_point_in_rectangle(p_in1, box)
        assert ste.is_point_in_rectangle(p_in2, box)
        assert !ste.is_point_in_rectangle(p_out1, box)
        assert !ste.is_point_in_rectangle(p_out2, box)
        assert !ste.is_point_in_rectangle(p_out3, box)
        assert !ste.is_point_in_rectangle(p_out4, box)
      end

      def test_closest_point_in_segment
        ste = ::Panatrans::KmlExtractor::StopTimesExtractor.new(nil,nil)
        segment_start = {lat:0.0, lon: 0.0}
        segment_end = {lat:0.0, lon: 10.0}

        #All are on the left
        point_arr1 = [{lat:1.0, lon: 1.0}, {lat: 2.0, lon: 2.0}]
        r1 = ste.closest_point_to_segment_at_right(point_arr1,segment_start, segment_end)
        assert_nil r1

        #only the first point is on the right
        point_arr2 = [{lat:-1.0, lon: 1.0}, {lat: 2.0, lon: 2.0}]
        r2 = ste.closest_point_to_segment_at_right(point_arr2,segment_start, segment_end)
        assert_equal(-1.0, r2[:lat])
        assert_equal 1.0, r2[:lon]

        # Two points on the right, select closer
        point_arr3 = [{lat:-1.0, lon: 1.0}, {lat: -2.0, lon: 2.0}, {lat: -3.0,lon: 3.0}]
        r3 = ste.closest_point_to_segment_at_right(point_arr3,segment_start, segment_end)
        assert_equal(-1.0, r3[:lat])
        assert_equal 1.0, r3[:lon]

        # Two points on the right, but there is one on the left closer
        point_arr4 = [{lat:-1.0, lon: 1.0}, {lat: -2.0, lon: 2.0},{lat:0.5,lon:0.5}]
        r4 = ste.closest_point_to_segment_at_right(point_arr4,segment_start, segment_end)
        assert_equal(-1.0, r4[:lat])
        assert_equal 1.0, r4[:lon]

        # The segment goes on the other direction
        point_arr5 = [{lat:-1.0, lon: 1.0}, {lat: -2.0, lon: 2.0},{lat:0.5,lon:0.5}]
        r5 = ste.closest_point_to_segment_at_right(point_arr5,segment_end, segment_start)
        assert_equal 0.5, r5[:lat]
        assert_equal 0.5, r5[:lon]
      end

end
