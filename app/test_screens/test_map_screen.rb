class TestMapScreen < PM::MapScreen
  attr_accessor :infinite_loop_points, :request_complete, :action_called
  attr_accessor :got_will_change_region, :got_on_change_region

  mapbox_setup access_token: "YOU_MAPBOX_ACCESS_TOKEN",
    tile_source: "mylogin.map"

  start_position latitude: -23.156386, longitude: -44.235521, radius: 75, zoom: 5
  title "Ilha Grande, RJ"
  tap_to_add length: 1.5, annotation: {animates_drop: false, title: "Uma nova praia?"}

  def on_load
    @action_called = false
    @got_will_change_region = false
    @got_on_change_region = false
  end

  def promotion_annotation_data
    @promotion_annotation_data
  end

  def annotation_data
    # Partial set of data from "GPS Map of Gorges State Park": http://www.hikewnc.info/maps/gorges-state-park/gps-map
    @data ||= [
    {
      latitude: -23.156386,
      longitude: -44.235521,
      title: "Ilha Grande",
      subtitle: "Parque Nacional da Ilha Grande",
      image: UIImage.imageNamed("park2")
    },{
      # Example of using :coordinate instead of :latitude & :longitude
      coordinate: CLLocationCoordinate2DMake(-23.171329, -44.127505),
      title: "Praia de Lopes Mendes",
      subtitle: "Ilha Grande - SE",
      pin_color: :red,
      action: :my_action
    },{
      longitude: -44.166854,
      latitude: -23.140548,
      title: "Vila do Abraão",
      maki_icon: 'ferry'
    }]
  end

  def lookup_infinite_loop
    self.request_complete = false
    self.look_up_address address: "1 Infinite Loop" do |points, error|
      self.request_complete = true
      self.infinite_loop_points = points
    end
  end

  def my_action
    @action_called = true
  end

  def will_change_region
    @got_will_change_region = true
  end

  def on_change_region
    @got_on_change_region = true
  end

end
