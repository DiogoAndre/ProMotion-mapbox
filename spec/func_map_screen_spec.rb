describe "ProMotion::TestMapScreen functionality" do
  tests TestMapScreen

  def map_screen
    @map_screen ||= TestMapScreen.new(nav_bar: true)
  end

  def controller
    map_screen.navigationController
  end

  def default_annotation
    {
      longitude: -82.965972900392,
      latitude: 35.090648651124,
      title: "My Cool Image Pin",
      subtitle: "Image pin subtitle"
    }
  end

  def add_image_annotation
    ann = default_annotation.merge({
      image: UIImage.imageNamed("test.png")
    })
    map_screen.annotations.count.should == 3
    map_screen.add_annotation ann
    map_screen.set_region map_screen.region(map_screen.annotations.last.coordinate, 5)
  end

  after do
    map_screen = nil
  end

  it "should have a navigation bar" do
    map_screen.navigationController.should.be.kind_of(UINavigationController)
  end

  it "should start the map in the correct location" do
    center_coordinate = map_screen.center
    center_coordinate.latitude.should.be.close -23.156386, 0.02
    center_coordinate.longitude.should.be.close -44.235521, 0.02
  end

  it "should move the map center" do
    wait 0.05 do
      map_screen.center = {latitude: -23.256386, longitude: -44.235521, animated: true}
      wait 0.75 do
        center_coordinate = map_screen.center
        center_coordinate.latitude.should.be.close -23.256386, 0.02
        center_coordinate.longitude.should.be.close -44.235521, 0.02
      end
    end
  end

  it "should select an annotation" do
    map_screen.selected_annotation.should == nil
    map_screen.select_annotation map_screen.annotations.first
    wait 0.75 do
      map_screen.selected_annotation == map_screen.annotations.first
    end
    map_screen.deselect_annotation map_screen.annotations.first
  end

  it "should select an annotation by index" do
    map_screen.selected_annotation.should == nil
    map_screen.select_annotation_at 1
    wait 0.75 do
      map_screen.selected_annotation.should == map_screen.annotations[1]
      map_screen.deselect_annotation map_screen.annotations.first
    end    
  end

  it "should select another annotation and check that the title is correct" do
    map_screen.selected_annotation.should == nil
    map_screen.select_annotation map_screen.annotations[1]
    wait 0.75 do
      map_screen.selected_annotation == map_screen.annotations.first
    end

    map_screen.selected_annotation.title.should == "Praia de Lopes Mendes"
    map_screen.selected_annotation.subtitle.should == "Ilha Grande - SE"

  end

  it "should deselect selected annotations" do
    map_screen.select_annotation map_screen.annotations.last
    wait 0.75 do
      # map_screen.selected_annotations.count.should == 1
    end

    map_screen.deselect_annotation
    wait 0.75 do
      map_screen.selected_annotation.should == nil
    end
  end

  it "should add an annotation and be able to zoom immediately" do
    ann = {
      longitude: -82.966093558105,
      latitude: 35.092520895652,
      title: "Something Else"
    }
    map_screen.annotations.count.should == 3
    map_screen.add_annotation ann
    map_screen.annotations.count.should == 4
    map_screen.set_region map_screen.region(map_screen.annotations.last.coordinate, 5)
    map_screen.select_annotation map_screen.annotations.last
    map_screen.deselect_annotation
  end

  it "should be able to overwrite all annotations" do
    anns = [{
      longitude: -122.029620,
      latitude: 37.331789,
      title: "My Cool Pin"
    },{
      longitude: -80.8498118 ,
      latitude: 35.2187218,
      title: "My Cool Pin"
    }]
    map_screen.annotations.count.should == 3
    map_screen.add_annotations anns
    map_screen.annotations.count.should == 2
  end

  it "should add an image based annotation" do
    add_image_annotation
    map_screen.annotations.count.should == 4

    checking = map_screen.annotations.last
    %w(title subtitle coordinate).each do |method|
      defined?(checking.send(method.to_sym)).nil?.should.be.false
    end
  end

  it "should select an image annotation" do
    add_image_annotation
    map_screen.selected_annotation.should == nil
    map_screen.select_annotation map_screen.annotations.last
    wait 0.75 do
      map_screen.selected_annotation == map_screen.annotations.last
      map_screen.deselect_annotation
    end
  end

  it "should select an image annotation by index" do
    add_image_annotation
    map_screen.selected_annotation.should == nil
    map_screen.select_annotation_at 3
    wait 0.75 do
      map_screen.selected_annotation.should == map_screen.annotations[3]
      map_screen.deselect_annotation
    end
  end

  it "should select an image annotation and check that the title is correct" do
    add_image_annotation
    map_screen.selected_annotation.should == nil
    map_screen.select_annotation map_screen.annotations[3]
    wait 0.75 do
      map_screen.selected_annotation.should == map_screen.annotations[3]
    end
    map_screen.selected_annotation.title.should == "My Cool Image Pin"
    map_screen.selected_annotation.subtitle.should == "Image pin subtitle"
  end

  it "should allow setting a leftCalloutAccessoryView" do
    btn = UIButton.new
    ann = {
      longitude: -82.965972900392,
      latitude: 35.090648651124,
      title: "My Cool Image Pin",
      subtitle: "Image pin subtitle",
      left_accessory: btn
    }
    map_screen.add_annotation ann
    annot = map_screen.annotations.last
    annot.should.be.kind_of?(ProMotion::MapScreenAnnotation)
    v = map_screen.annotation_view(map_screen.view, annot)
    v.leftCalloutAccessoryView.should == btn
  end

  it "should allow setting a rightCalloutAccessoryView" do
    btn = UIButton.new
    ann = {
      longitude: -82.965972900392,
      latitude: 35.090648651124,
      title: "My Cool Image Pin",
      subtitle: "Image pin subtitle",
      right_accessory: btn
    }
    map_screen.add_annotation ann
    annot = map_screen.annotations.last
    annot.should.be.kind_of?(ProMotion::MapScreenAnnotation)
    v = map_screen.annotation_view(map_screen.view, annot)
    v.rightCalloutAccessoryView.should == btn
  end

  it "should call the correct action when set on an annotation" do
    ann = default_annotation.merge({
      action: :my_action
    })
    map_screen.add_annotation ann
    annot = map_screen.annotations.last
    annot.should.be.kind_of?(ProMotion::MapScreenAnnotation)
    v = map_screen.annotation_view(map_screen.mapview, annot)

    v.rightCalloutAccessoryView.class.should == UIButton
    v.rightCalloutAccessoryView.buttonType.should == UIButtonTypeDetailDisclosure

    map_screen.action_called.should == false
    v.rightCalloutAccessoryView.sendActionsForControlEvents(UIControlEventTouchUpInside)
    map_screen.action_called.should == true
  end

  it "should allow a user to set an action with a custom button type" do
    ann = default_annotation.merge({
      action: :my_action_with_sender,
      action_button_type: UIButtonTypeContactAdd
    })
    map_screen.add_annotation ann
    annot = map_screen.annotations.last
    annot.should.be.kind_of?(ProMotion::MapScreenAnnotation)
    v = map_screen.annotation_view(map_screen.mapview, annot)

    v.rightCalloutAccessoryView.class.should == UIButton
    v.rightCalloutAccessoryView.buttonType.should == UIButtonTypeContactAdd
  end

  it 'should allow you to set different properties of RMMapView' do
    map_screen.map.hideAttribution.should == false
    map_screen.map.hideAttribution = true
    map_screen.map.hideAttribution.should == true

    map_screen.map.draggingEnabled.should == true
    map_screen.map.draggingEnabled = false
    map_screen.map.draggingEnabled.should == false

    map_screen.map.bouncingEnabled.should == false
    map_screen.map.bouncingEnabled = true
    map_screen.map.bouncingEnabled.should == true
  end

  it "can lookup a location with a CLLocation" do
    location = CLLocation.alloc.initWithLatitude(-34.226082, longitude: 150.668374)

    map_screen.look_up_location(location) do |placemarks, fetch_error|
      @error = fetch_error
      @placemark = placemarks.first
      resume
    end

    wait do
      @error.should == nil
      @placemark.should.be.kind_of?(CLPlacemark)
      @error = nil
      @placemark = nil
    end
  end

  it "can lookup a location with a CLLocationCoordinate2D" do
    location = CLLocationCoordinate2DMake(-34.226082, 150.668374)

    map_screen.look_up_location(location) do |placemarks, fetch_error|
      @error = fetch_error
      @placemark = placemarks.first
      resume
    end

    wait do
      @error.should == nil
      @placemark.should.be.kind_of?(CLPlacemark)
      @error = nil
      @placemark = nil
    end
  end

  it "should call will_change_region" do
    map_screen.on_load
    map_screen.got_will_change_region.should == false
    map_screen.mapView(map_screen.map, regionWillChangeAnimated: true)
    map_screen.got_will_change_region.should == true
  end

  it "should call on_change_region" do
    map_screen.on_load
    map_screen.got_on_change_region.should == false
    map_screen.mapView(map_screen.map, regionDidChangeAnimated: true)
    map_screen.got_on_change_region.should == true
  end
end
