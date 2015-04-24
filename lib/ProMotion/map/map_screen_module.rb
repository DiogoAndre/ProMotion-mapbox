module ProMotion
  module MapScreenModule

    PIN_COLORS = {
      red: UIColor.redColor,
      green: UIColor.greenColor,
      purple: UIColor.purpleColor
    }
        
    def screen_setup
      mapbox_setup
      self.view = nil
      self.view = RMMapView.alloc.initWithFrame(self.view.bounds, andTilesource:@tileSource)
      self.view.delegate = self
      check_annotation_data
      @promotion_annotation_data = []
      set_up_tap_to_add
    end
    
    def mapbox_setup
      if self.class.respond_to?(:get_mapbox_setup) && self.class.get_mapbox_setup
        setup_params = self.class.get_mapbox_setup_params
      else
        PM.logger.error "Missing Mapbox setup data."
      end
      RMConfiguration.sharedInstance.setAccessToken(setup_params[:access_token]) if RMConfiguration.sharedInstance.accessToken.nil?
      @tileSource = RMMapboxSource.alloc.initWithMapID(setup_params[:tile_source])
    end
    
    def view_will_appear(animated)
      super
      update_annotation_data
      set_up_start_center
    end

    def view_did_appear(animated)
      super
      set_up_start_region
    end
    
    def check_annotation_data
      PM.logger.error "Missing #annotation_data method in MapScreen #{self.class.to_s}." unless self.respond_to?(:annotation_data)
    end

    def update_annotation_data
      clear_annotations
      add_annotations annotation_data
    end
    
    def map
      self.view
    end
    alias_method :mapview, :map

    def center
      self.view.centerCoordinate
    end

    def center=(params={})
      PM.logger.error "Missing #:latitude property in call to #center=." unless params[:latitude]
      PM.logger.error "Missing #:longitude property in call to #center=." unless params[:longitude]
      params[:animated] ||= true

      # Set the new region
      self.view.setCenterCoordinate(
        CLLocationCoordinate2D.new(params[:latitude], params[:longitude]),
        animated:params[:animated]
      )
    end

    def show_user_location
      if location_manager.respondsToSelector('requestWhenInUseAuthorization')
        location_manager.requestWhenInUseAuthorization
      end

      set_show_user_location true
    end

    def hide_user_location
      set_show_user_location false
    end

    def set_show_user_location(show)
      self.view.showsUserLocation = show
    end

    def showing_user_location?
      self.view.showsUserLocation
    end

    def user_location
      user_annotation.nil? ? nil : user_annotation.coordinate
    end

    def user_annotation
      self.view.userLocation.nil? ? nil : self.view.userLocation.location
    end

    def zoom_to_user(radius = 0.05, animated=true)
      show_user_location unless showing_user_location?
      set_region(create_region(user_location,radius), animated)
    end

    def annotations
      @promotion_annotation_data
    end

    def select_annotation(annotation, animated=true)
      self.view.selectAnnotation(annotation, animated:animated)
    end

    def select_annotation_at(annotation_index, animated=true)
      select_annotation(annotations[annotation_index], animated:animated)
    end

    def selected_annotation
      self.view.selectedAnnotation
    end

    def deselect_annotation(animated=false)
      unless selected_annotation.nil?
        self.view.deselectAnnotation(selected_annotation, animated:animated)
      end
    end

    def add_annotation(annotation)
      @promotion_annotation_data << MapScreenAnnotation.new(annotation,self.view)
      self.view.addAnnotation @promotion_annotation_data.last
    end

    def add_annotations(annotations)
      @promotion_annotation_data = Array(annotations).map{|a| MapScreenAnnotation.new(a,self.view)}
      self.view.addAnnotations @promotion_annotation_data
    end

    def clear_annotations
      @promotion_annotation_data.each do |a|
        self.view.removeAnnotation(a)
      end
      @promotion_annotation_data = []
    end

    def annotation_view(map_view, annotation)
      return if annotation.is_a? RMUserLocation

      params = annotation.params

      identifier = params[:identifier]
      # Set the pin properties
      if params[:image]
        view = RMMarker.alloc.initWithUIImage(params[:image])
      else
        pinColor = (PIN_COLORS[params[:pin_color]] || params[:pin_color])
        view = RMMarker.alloc.initWithMapboxMarkerImage(params[:maki_icon], tintColor: pinColor)
      end
      view.annotation = annotation
      view.canShowCallout = params[:show_callout] if view.respond_to?("canShowCallout=")

      if params[:left_accessory]
        view.leftCalloutAccessoryView = params[:left_accessory]
      end
      if params[:right_accessory]
        view.rightCalloutAccessoryView = params[:right_accessory]
      end

      if params[:action]
        button_type = params[:action_button_type] || UIButtonTypeDetailDisclosure

        action_button = UIButton.buttonWithType(button_type)
        action_button.addTarget(self, action: params[:action], forControlEvents:UIControlEventTouchUpInside)

        view.rightCalloutAccessoryView = action_button
      end
      view
    end

    def set_start_position(params={})
      params = {
        latitude: 37.331789,
        longitude: -122.029620,
        radius: 10
      }.merge(params)
      initialLocation = CLLocationCoordinate2D.new(params[:latitude], params[:longitude])
      region = create_region(initialLocation,params[:radius])
      set_region(region, animated:false)
    end

    def set_up_start_region
      if self.class.respond_to?(:get_start_position) && self.class.get_start_position
        start_params = self.class.get_start_position_params
        self.set_start_position start_params unless start_params[:radius].nil?
      end
    end
    
    def set_up_start_center
      if self.class.respond_to?(:get_start_position) && self.class.get_start_position
        start_params = self.class.get_start_position_params
        start_params[:zoom] ||= 5
        self.view.setZoom(start_params[:zoom], atCoordinate: 
          CLLocationCoordinate2D.new(start_params[:latitude], start_params[:longitude]), 
          animated: false
        )
      end
    end

    def set_tap_to_add(params={})
      params = {
        length: 2.0,
        target: self,
        action: "gesture_drop_pin:",
        annotation: {
          title: "Dropped Pin",
          animates_drop: true
        }
      }.merge(params)
      @tap_to_add_annotation_params = params[:annotation]

      lpgr = UILongPressGestureRecognizer.alloc.initWithTarget(params[:target], action:params[:action])
      lpgr.minimumPressDuration = params[:length]
      self.view.addGestureRecognizer(lpgr)
    end

    def gesture_drop_pin(gesture_recognizer)
      if gesture_recognizer.state == UIGestureRecognizerStateBegan
        NSNotificationCenter.defaultCenter.postNotificationName("ProMotionMapWillAddPin", object:nil)
        touch_point = gesture_recognizer.locationInView(self.view)
        touch_map_coordinate = self.view.convertPoint(touch_point, toCoordinateFromView:self.view)

        add_annotation({
          coordinate: touch_map_coordinate
        }.merge(@tap_to_add_annotation_params))
        NSNotificationCenter.defaultCenter.postNotificationName("ProMotionMapAddedPin", object:@promotion_annotation_data.last)
      end
    end

    def set_up_tap_to_add
      if self.class.respond_to?(:get_tap_to_add) && self.class.get_tap_to_add
        self.set_tap_to_add self.class.get_tap_to_add_params
      end
    end

    # TODO: Why is this so complex?
    def zoom_to_fit_annotations(args={})
      # Preserve backwards compatibility
      args = {animated: args} if args == true || args == false
      args = {animated: true, include_user: false}.merge(args)

      ann = args[:include_user] ? (annotations + [user_annotation]).compact : annotations

      #Don't attempt the rezoom of there are no pins
      return if ann.count == 0

      #Set some crazy boundaries
      topLeft = CLLocationCoordinate2D.new(-90, 180)
      bottomRight = CLLocationCoordinate2D.new(90, -180)

      #Find the bounds of the pins
      ann.each do |a|
        topLeft.longitude = [topLeft.longitude, a.coordinate.longitude].min
        topLeft.latitude = [topLeft.latitude, a.coordinate.latitude].max
        bottomRight.longitude = [bottomRight.longitude, a.coordinate.longitude].max
        bottomRight.latitude = [bottomRight.latitude, a.coordinate.latitude].min
      end

      #Find the bounds of all the pins and set the map_view
      coord = CLLocationCoordinate2D.new(
        topLeft.latitude - (topLeft.latitude - bottomRight.latitude) * 0.5,
        topLeft.longitude + (bottomRight.longitude - topLeft.longitude) * 0.5
      )

      # Add some padding to the edges
      span = MKCoordinateSpanMake(
        ((topLeft.latitude - bottomRight.latitude) * 1.075).abs,
        ((bottomRight.longitude - topLeft.longitude) * 1.075).abs
      )

      region = MKCoordinateRegionMake(coord, span)
      fits = self.view.regionThatFits(region)

      set_region(fits, animated: args[:animated])
    end

    def set_region(region, animated=true)
      self.view.zoomWithLatitudeLongitudeBoundsSouthWest(
        region[:southWest],
        northEast: region[:northEast], 
        animated: animated
      )
    end
        
    def deg_to_rad(angle)
      angle*Math::PI/180
    end

    def rad_to_deg(angle)
      angle*180/Math::PI
    end

    # Input coordinates and bearing in decimal degrees, distance in kilometers
    def point_from_location_bearing_and_distance(initialLocation, bearing, distance)
      distance = distance / 6371.01 # Convert to angular radians dividing by the Earth radius
      bearing = deg_to_rad(bearing)
      input_latitude = deg_to_rad(initialLocation.latitude)
      input_longitude = deg_to_rad(initialLocation.longitude)

      output_latitude = Math.asin( 
                          Math.sin(input_latitude) * Math.cos(distance) + 
                          Math.cos(input_latitude) * Math.sin(distance) * 
                          Math.cos(bearing)
                        )
      
      dlon = input_longitude + Math.atan2(
                                Math.sin(bearing) * Math.sin(distance) * 
                                Math.cos(input_longitude), Math.cos(distance) - 
                                Math.sin(input_longitude) * Math.sin(output_latitude)
                              )
      
      output_longitude = (dlon + 3*Math::PI) % (2*Math::PI) - Math::PI  
      CLLocationCoordinate2DMake(rad_to_deg(output_latitude), rad_to_deg(output_longitude))
    end
    
    def create_region(initialLocation,radius=10)
      return nil unless initialLocation.is_a? CLLocationCoordinate2D
      radius = radius * 1.820 # Meters equivalent to 1 Nautical Mile
      southWest = self.point_from_location_bearing_and_distance(initialLocation,225, radius)
      northEast = self.point_from_location_bearing_and_distance(initialLocation,45, radius)
      {:southWest => southWest, :northEast => northEast}
    end
    alias_method :region, :create_region
    
    def look_up_address(args={}, &callback)
      args[:address] = args if args.is_a? String # Assume if a string is passed that they want an address

      geocoder = CLGeocoder.new
      return geocoder.geocodeAddressDictionary(args[:address], completionHandler: callback) if args[:address].is_a?(Hash)
      return geocoder.geocodeAddressString(args[:address].to_s, completionHandler: callback) unless args[:region]
      return geocoder.geocodeAddressString(args[:address].to_s, inRegion:args[:region].to_s, completionHandler: callback) if args[:region]
    end

    def look_up_location(location, &callback)
      location = CLLocation.alloc.initWithLatitude(location.latitude, longitude:location.longitude) if location.is_a?(CLLocationCoordinate2D)

      if location.kind_of?(CLLocation)
        geocoder = CLGeocoder.new
        geocoder.reverseGeocodeLocation(location, completionHandler: callback)
      else
        PM.logger.info("You're trying to reverse geocode something that isn't a CLLocation")
        callback.call nil, nil
      end
    end

    def empty_cache
      map.removeAllCachedImages
    end

    ########## Mapbox methods #################
    def mapView(map_view, layerForAnnotation: annotation)
      if annotation.is_a?(RMAnnotation)
        annotation = MapScreenAnnotation.new_with_rmannotation(annotation,self.view)
      end
      annotation_view(map_view, annotation)
    end

    ########## Cocoa touch methods #################
    def mapView(map_view, didUpdateUserLocation:userLocation)
      if self.respond_to?(:on_user_location)
        on_user_location(userLocation)
      else
        PM.logger.info "You're tracking the user's location but have not implemented the #on_user_location(location) method in MapScreen #{self.class.to_s}."
      end
    end

    def mapView(map_view, regionWillChangeAnimated:animated)
      if self.respond_to?("will_change_region:")
        will_change_region(animated)
      elsif self.respond_to?(:will_change_region)
        will_change_region
      end
    end

    def mapView(map_view, regionDidChangeAnimated:animated)
      if self.respond_to?("on_change_region:")
        on_change_region(animated)
      elsif self.respond_to?(:on_change_region)
        on_change_region
      end
    end

    def tapOnCalloutAccessoryControl(control, forAnnotation: annotation, onMap: map)
      control.sendActionsForControlEvents(UIControlEventTouchUpInside)
    end
    ########## Cocoa touch Ruby counterparts #################

    def deceleration_mode
      map.decelerationMode
    end

    def deceleration_mode=(mode)
      map.decelerationMode = mode
    end

    %w(dragging bouncing clustering).each do |meth|
      define_method("#{meth}_enabled?") do
        map.send("#{meth}Enabled")
      end

      define_method("#{meth}_enabled=") do |argument|
        map.send("#{meth}Enabled=", argument)
      end
    end

    module MapClassMethods
      # Start Position
      def start_position(params={})
        @start_position_params = params
        @start_position = true
      end

      def get_start_position_params
        @start_position_params ||= nil
      end

      def get_start_position
        @start_position ||= false
      end

      # Tap to drop pin
      def tap_to_add(params={})
        @tap_to_add_params = params
        @tap_to_add = true
      end

      def get_tap_to_add_params
        @tap_to_add_params ||= nil
      end

      def get_tap_to_add
        @tap_to_add ||= false
      end
      
      # Mapbox setup
      def mapbox_setup(params={})
        @mapbox_setup_params = params
        @mapbox_setup = true
      end
      
      def get_mapbox_setup_params
        @mapbox_setup_params ||= nil
      end
      
      def get_mapbox_setup
        @mapbox_setup ||= false
      end
      

    end
    def self.included(base)
      base.extend(MapClassMethods)
    end

    private

    def location_manager
      @location_manager ||= CLLocationManager.alloc.init
      @location_manager.delegate ||= self
      @location_manager
    end

  end
end
