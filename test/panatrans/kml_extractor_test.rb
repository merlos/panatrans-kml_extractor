require 'test_helper'
require 'panatrans/kml_extractor'

class Panatrans::KmlExtractorTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Panatrans::KmlExtractor::VERSION
  end

  def setup
    #radius used in tests
    @radius = 111194.9 # meters  = 1 degree in latitude.

    @kml_string = File.open('test/fixtures/test.kml', 'r') { |f| f.read }
    @kml = Nokogiri::XML(open('./test/fixtures/test.kml'))
    @gtfs_stops_file_path = './test/fixtures/stops.txt'
    @kml_stop = nil
    @kml_route_placemark = nil
    @kml_stop_folder = nil
    @kml_route_folder = nil
    @kml.css('Folder').each do |folder|
      if folder.at_css('name').content == 'Rutas_por_parada' then
        @kml_stop_folder = folder
        folder.css('Placemark').each do |placemark|
          @kml_stop = placemark if placemark.at_css('name').content == 'TestStop'
        end
      end
      if folder.at_css('name').content == 'RUTAS_METROBUS_2016' then
        @kml_route_folder = folder
        folder.css('Placemark').each do |placemark|
          @kml_route_placemark = placemark if placemark.at_css('name').content == 'TestRoute'
        end
      end
    end #kml folder
    @s = ::Panatrans::KmlExtractor::Stop.new_from_kml(1, @kml_stop)
    @r = ::Panatrans::KmlExtractor::Route.new(1, @kml_route_placemark)
  end #setup


    def test_kml_stop_was_set_on_setup
      assert_equal 'TestStop', @kml_stop.at_css('name').content
    end

    def test_kml_route_placemark_was_set_on_setup
      assert_equal 'TestRoute', @kml_route_placemark.at_css('name').content
    end

    # Stop tests
    def test_stop_constructor
      s = ::Panatrans::KmlExtractor::Stop.new_from_kml(1, @kml_stop)
      assert_equal 'TestStop', s.name
    end

    def test_stop_coords_method
      r = ::Panatrans::KmlExtractor::Stop.new(9.0, 8.0)
      r.coords = {lat: 1.0, lon:2.0}
      assert_equal 1.0, r.lat
      assert_equal 2.0, r.lon
    end

    def test_route_placemark_constructor
      r = ::Panatrans::KmlExtractor::Route.new(1, @kml_route_placemark)
      assert_equal 'TestRoute', r.name
    end

    def test_stop_to_gtfs_stop_row
      row = @s.to_gtfs_stop_row
      assert_equal "1", row[:stop_id]
      assert_equal "TestStop", row[:stop_name]
      assert_equal(-80.000001, row[:stop_lon])
      assert_equal 9.000000, row[:stop_lat]
    end

    def test_stop_constructor_from_gtfs
      row = @s.to_gtfs_stop_row
      s2 = ::Panatrans::KmlExtractor::Stop.new_from_gtfs_row(row)
      assert_equal "1", s2.id
      assert_equal "TestStop", s2.name
      assert_equal(-80.000001, s2.lon)
      assert_equal 9.000000, s2.lat
    end

    def test_is_stop_in_box
      box = {min_lat: 8.0, max_lat: 10.0, min_lon: -81.0, max_lon: -79.0}
      # point is inside
      assert @s.is_stop_in_box(box)
      # point is outside
      box2 = {min_lat: 0.0, max_lat: 10.0, min_lon: 0.0, max_lon: 20.0}
      assert !@s.is_stop_in_box(box2)
    end

      # StopList tests
      def test_stop_list_add_kml_stop
        sl = ::Panatrans::KmlExtractor::StopList.new
        sl.add_kml_stop(1, @kml_stop)
        assert_equal 1, sl.count
        assert_equal 1, sl[0].id
        assert_equal 'TestStop', sl[0].name
      end

      def test_stop_list_add_folder
        sl = ::Panatrans::KmlExtractor::StopList.new
        sl.add_kml_stop_folder(@kml_stop_folder)
        assert_equal 4, sl.count
      end

      def test_stop_list_new_from_gtfs_stops_file
        sl = ::Panatrans::KmlExtractor::StopList.new_from_gtfs_stops_file(@gtfs_stops_file_path)
        assert_equal 2, sl.count
        assert_equal '30', sl[0].id
        assert_equal 'Albrook', sl[0].name
        assert_equal 8.961709, sl[1].lat
        assert_equal(-79.538752, sl[1].lon)


      end

      def test_stop_list_includes_stop
        sl = ::Panatrans::KmlExtractor::StopList.new
        sl.add_kml_stop_folder(@kml_stop_folder)
        assert_equal 4, sl.count
        assert sl.includes_stop(@s)
      end

      def test_stop_list_stops_in_box
        box = {min_lat: 8.999999, max_lat: 9.000001, min_lon: -80.01000, max_lon: -79.999}
        sl = ::Panatrans::KmlExtractor::StopList.new
        sl.add_kml_stop_folder(@kml_stop_folder)
        stops_in_box = sl.stops_in_box(box)
        #pp stops_in_box
        assert_equal 1, stops_in_box.count
        assert_equal 'TestStop', stops_in_box[0].name
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

      # Route tests
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

      # RouteList
      def test_route_placemark_list
        rpl = ::Panatrans::KmlExtractor::RouteList.new
        rpl.add_route_folder(@kml_route_folder)
        assert 3, rpl.count
      end

      #StopTimesExtractor
      def test_bounding_box

        p0 = ::Panatrans::KmlExtractor::LatLon.new(0.0, 0.0) # +/-1 deg in lat, +/-1 in lon
        p1 = ::Panatrans::KmlExtractor::LatLon.new(60.0,1.0) # 1 deg in lat, +/- 0.5 (cos(60)) in lon
        ste = ::Panatrans::KmlExtractor::StopTimesExtractor.new(nil,nil)
        box = ste.bounding_box(p0,p1,@radius)
        #puts box
        assert_equal 61.0, box[:max_lat]
        assert_equal(-1.0, box[:min_lat])
        assert_equal 1.5, box[:max_lon]
        assert_equal(-1.0, box[:min_lon])
      end

      def test_point_bounding_box

        p0 = ::Panatrans::KmlExtractor::LatLon.new(0.0, 0.0) # +/-1 deg in lat, +/-1 in lon
        ste = ::Panatrans::KmlExtractor::StopTimesExtractor.new(nil,nil)
        box = ste.point_bounding_box(p0,@radius)
        #puts box
        assert_equal 1.0, box[:max_lat]
        assert_equal(-1.0, box[:min_lat])
        assert_equal 1.0, box[:max_lon]
        assert_equal(-1.0, box[:min_lon])
      end

      def test_is_point_in_rectangle
        ste = ::Panatrans::KmlExtractor::StopTimesExtractor.new(nil,nil)
        box = {min_lat: -2, max_lat: 2, min_lon: -2, max_lon: 2}
        # points inside
        p_in1 = ::Panatrans::KmlExtractor::Stop.new_from_point(1, {lat: -1.0, lon: -1.0})
        p_in2 = ::Panatrans::KmlExtractor::Stop.new_from_point(2, {lat: 1.0, lon: 1.0 })

        # points outside
        p_out1 = ::Panatrans::KmlExtractor::Stop.new_from_point(10,{lat: -3.0, lon: 1.0})
        p_out2 = ::Panatrans::KmlExtractor::Stop.new_from_point(11,{lat: 3.0, lon: 1.0 })
        p_out3 = ::Panatrans::KmlExtractor::Stop.new_from_point(12,{lat: 1.0, lon: -3.0 })
        p_out4 = ::Panatrans::KmlExtractor::Stop.new_from_point(13,{lat: 1.0, lon: 3.0 })

        assert ste.is_point_in_rectangle(p_in1, box)
        assert ste.is_point_in_rectangle(p_in2, box)
        assert !ste.is_point_in_rectangle(p_out1, box)
        assert !ste.is_point_in_rectangle(p_out2, box)
        assert !ste.is_point_in_rectangle(p_out3, box)
        assert !ste.is_point_in_rectangle(p_out4, box)
      end

      def test_closest_point
        ste = ::Panatrans::KmlExtractor::StopTimesExtractor.new(nil,nil)
        point_arr1 = [
          ::Panatrans::KmlExtractor::Stop.new_from_point(1,{lat:1.0, lon: 1.0}),
          ::Panatrans::KmlExtractor::Stop.new_from_point(2,{lat: 2.0, lon: 2.0})
        ]
        point = ::Panatrans::KmlExtractor::Stop.new_from_point(1,{lat: 0.0, lon: 0.0})
        # test nil
        r1 = ste.closest_point(nil, point)
        assert_nil r1

        r2 = ste.closest_point([],point)
        assert_nil r2

        r3 = ste.closest_point(point_arr1, point)
        assert_equal 1.0, r3.lat
        assert_equal 1.0, r3.lon
      end

      def test_closest_point_in_segment
        ste = ::Panatrans::KmlExtractor::StopTimesExtractor.new(nil,nil)
        # lat 0.0, lon 0.0
        segment_start = ::Panatrans::KmlExtractor::ShapePoint.new('shape_id', 0, 0.0, 0.0)
        # lat 0.0, lon 0.0
        segment_end = ::Panatrans::KmlExtractor::ShapePoint.new('shape_id', 1, 0.0, 10.0)

        #All are on the left
        point_arr1 = [
            ::Panatrans::KmlExtractor::Stop.new_from_point(1, {lat:1.0, lon: 1.0}),
            ::Panatrans::KmlExtractor::Stop.new_from_point(2, {lat: 2.0, lon: 2.0})
          ]
        r1 = ste.closest_point_to_segment_at_right(point_arr1,segment_start, segment_end)
        assert_nil r1

        #only the first point is on the right
        point_arr2 = [
          ::Panatrans::KmlExtractor::Stop.new_from_point(1, {lat:-1.0, lon: 1.0}),
          ::Panatrans::KmlExtractor::Stop.new_from_point(2, {lat: 2.0, lon: 2.0})
        ]
        r2 = ste.closest_point_to_segment_at_right(point_arr2,segment_start, segment_end)
        assert_equal(-1.0, r2.lat)
        assert_equal 1.0, r2.lon

        # Two points on the right, select closer
        point_arr3 = [
          ::Panatrans::KmlExtractor::Stop.new_from_point(1,{lat:-1.0, lon: 1.0}),
          ::Panatrans::KmlExtractor::Stop.new_from_point(2,{lat: -2.0, lon: 2.0}),
          ::Panatrans::KmlExtractor::Stop.new_from_point(4,{lat: -3.0,lon: 3.0})
        ]
        r3 = ste.closest_point_to_segment_at_right(point_arr3,segment_start, segment_end)
        assert_equal(-1.0, r3.lat)
        assert_equal 1.0, r3.lon

        # Two points on the right, but there is one on the left closer
        point_arr4 = [
          ::Panatrans::KmlExtractor::Stop.new_from_point(1, {lat:-1.0, lon: 1.0}),
          ::Panatrans::KmlExtractor::Stop.new_from_point(2, {lat: -2.0, lon: 2.0}),
          ::Panatrans::KmlExtractor::Stop.new_from_point(3, {lat:0.5,lon:0.5})
        ]
        r4 = ste.closest_point_to_segment_at_right(point_arr4,segment_start, segment_end)
        assert_equal(-1.0, r4.lat)
        assert_equal 1.0, r4.lon

        # The segment goes on the other direction
        point_arr5 = [
          ::Panatrans::KmlExtractor::Stop.new_from_point(1,{lat:-1.0, lon: 1.0}),
          ::Panatrans::KmlExtractor::Stop.new_from_point(1,{lat: -2.0, lon: 2.0}),
          ::Panatrans::KmlExtractor::Stop.new_from_point(1,{lat:0.5,lon:0.5})
        ]
        r5 = ste.closest_point_to_segment_at_right(point_arr5,segment_end, segment_start)
        assert_equal 0.5, r5.lat
        assert_equal 0.5, r5.lon
      end

      def test_stop_time_extractor_run
        run_kml = Nokogiri::XML(open('./test/fixtures/run_test.kml'))
        sl = ::Panatrans::KmlExtractor::StopList.new
        kml_r1 = nil
        run_kml.css('Folder').each do |folder|
          if folder.at_css('name').content == 'Rutas_por_parada' then
            sl.add_kml_stop_folder(folder)
          end
          if folder.at_css('name').content == 'RUTAS_METROBUS_2016' then
            folder.css('Placemark').each do |placemark|
              kml_r1 = placemark if placemark.at_css('name').content == 'R1'
            end
          end
        end #run_kml folder
        route1 = ::Panatrans::KmlExtractor::Route.new(1, kml_r1)
        #basic checks to confirm file was correctly loaded
        assert_equal 5,sl.count
        assert_equal 5, route1.shape.count
        ste = ::Panatrans::KmlExtractor::StopTimesExtractor.new(route1,sl)

        ste.run(@radius)
        assert_equal 3, ste.route_stops.count
        assert_equal 5, ste.route_stops[0].id
        assert_equal 2, ste.route_stops[1].id
        assert_equal 1, ste.route_stops[2].id
      end

      def test_to_gtfs_stop_times_row
        ##------ Repeated code ---
        run_kml = Nokogiri::XML(open('./test/fixtures/run_test.kml'))
        sl = ::Panatrans::KmlExtractor::StopList.new
        kml_r1 = nil
        run_kml.css('Folder').each do |folder|
          if folder.at_css('name').content == 'Rutas_por_parada' then
            sl.add_kml_stop_folder(folder)
          end
          if folder.at_css('name').content == 'RUTAS_METROBUS_2016' then
            folder.css('Placemark').each do |placemark|
              kml_r1 = placemark if placemark.at_css('name').content == 'R1'
            end
          end
        end #run_kml folder
        route1 = ::Panatrans::KmlExtractor::Route.new(1, kml_r1)
        #basic checks to confirm file was correctly loaded
        assert_equal 5,sl.count
        assert_equal 5, route1.shape.count
        ste = ::Panatrans::KmlExtractor::StopTimesExtractor.new(route1,sl)
        ste.run(@radius)
        assert_equal 3, ste.route_stops.count
        # -- end of repeated code --
        stop_times = ste.to_gtfs_stop_times_rows
        assert_equal "trip_1", stop_times[0][:trip_id]
        assert_equal 5, stop_times[0][:stop_id]
        assert_equal 2, stop_times[1][:stop_sequence]
        assert_equal 1, stop_times[2][:stop_id]
      end

      def test_kml_file_constructor
        kml_file_path = './test/fixtures/run_test.kml'
        kml_file = ::Panatrans::KmlExtractor::KmlFile.new(kml_file_path)
        assert_equal 5, kml_file.stop_list.count
        assert_equal 1, kml_file.route_list.count

        kml_file_path = './test/fixtures/test.kml'
        kml_file = ::Panatrans::KmlExtractor::KmlFile.new(kml_file_path)
        assert_equal 4, kml_file.stop_list.count
        assert_equal 3, kml_file.route_list.count
      end

      def test_kml_gtfs_methods
        kml_file_path = './test/fixtures/run_test.kml'
        kml_file = ::Panatrans::KmlExtractor::KmlFile.new(kml_file_path)

        stops = kml_file.gtfs_stops
        assert_equal 5, stops.count
        # check one of the rows
        assert_equal 0.0, stops[4][:stop_lat]
        assert_equal 4.0, stops[4][:stop_lon]
        assert_equal "5", stops[4][:stop_id]
        routes = kml_file.gtfs_routes
        #pp routes
        # check the route
        assert_equal 1, routes.count
        assert_equal 'R1', routes[0][:route_short_name]
        assert_equal '1', routes[0][:route_id]

        trips = kml_file.gtfs_trips
        #pp trips
        # check route trips
        assert_equal 1, trips.count
        assert_equal 'trip_1', trips[0][:trip_id]
        assert_equal '1', trips[0][:route_id]

        shapes = kml_file.gtfs_shapes
        #pp shapes
        assert_equal 5, shapes.count
        assert_equal 0.00, shapes[0][:shape_pt_lat]
        assert_equal 3.00, shapes[1][:shape_pt_lon]

        stop_times = kml_file.gtfs_stop_times(@radius)
        assert_equal 3, stop_times.count
        assert_equal 5, stop_times[0][:stop_id]
        assert_equal 2, stop_times[1][:stop_id]
        assert_equal 1, stop_times[2][:stop_id]
      end

      def test_stop_time_extractor_run_with_small_radius
        kml_file_path = './test/fixtures/run_test.kml'
        kml_file = ::Panatrans::KmlExtractor::KmlFile.new(kml_file_path)
        s = kml_file.gtfs_stop_times(10)
        assert_equal 1, s.count
      end

end
