/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import MapKit
import QuartzCore

private let MAP_SPAN_DELTA = 0.05
private let MAP_LATITUDE_OFFSET = 0.015

class PlaceCarouselViewController: UIViewController {

    lazy var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        return manager
    }()

    // the top part of the background. Contains Number of Places, horizontal line & (soon to be) Current Location button
    lazy var headerView: PlaceCarouselHeaderView = {
        let view = PlaceCarouselHeaderView()
        return view
    }()

    // View that will display the sunset and sunrise times
    lazy var sunView: UIView = {
        let view = UIView()
        view.backgroundColor = Colors.carouselViewPlaceCardBackground

        view.layer.shadowColor = UIColor.darkGray.cgColor
        view.layer.shadowOpacity = 0.25
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 2
        view.layer.shouldRasterize = true

        return view
    }()

    // the map view
    lazy var mapView: MKMapView = {
        let view = MKMapView()
        view.translatesAutoresizingMaskIntoConstraints = false

        view.showsUserLocation = true
        view.isUserInteractionEnabled = false
        view.delegate = self
        return view
    }()

    // label displaying sunrise and sunset times
    lazy var sunriseSetTimesLabel: UILabel = {
        let label = UILabel()
        label.textColor = Colors.carouselViewSunriseSetTimesLabelText
        label.font = Fonts.carouselViewSunriseSetTimes
        return label
    }()

    lazy var placeCarousel = PlaceCarousel()

    override func viewDidLoad() {
        super.viewDidLoad()

        // add the views to the stack view
        view.addSubview(headerView)

        // setting up the layout constraints
        var constraints = [headerView.topAnchor.constraint(equalTo: view.topAnchor),
                           headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                           headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                           headerView.heightAnchor.constraint(equalToConstant: 150)]

        view.addSubview(sunView)
        constraints.append(contentsOf: [sunView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
                                        sunView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                                        sunView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                        sunView.heightAnchor.constraint(equalToConstant: 90)])

        view.insertSubview(mapView, belowSubview: sunView)
        constraints.append(contentsOf: [mapView.topAnchor.constraint(equalTo: sunView.bottomAnchor),
                                        mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                                        mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                        mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor)])


        // set up the subviews for the sunrise/set view
        sunView.addSubview(sunriseSetTimesLabel)
        constraints.append(sunriseSetTimesLabel.leadingAnchor.constraint(equalTo: sunView.leadingAnchor, constant: 20))
        constraints.append(sunriseSetTimesLabel.topAnchor.constraint(equalTo: sunView.topAnchor, constant: 14))

        // placeholder text for the labels
        headerView.numberOfPlacesLabel.text = "4 places"
        sunriseSetTimesLabel.text = "Sunset is at 6:14pm today"

        view.addSubview(placeCarousel.carousel)
        constraints.append(contentsOf: [placeCarousel.carousel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                                        placeCarousel.carousel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                        placeCarousel.carousel.topAnchor.constraint(equalTo: sunView.bottomAnchor, constant: -35),
                                        placeCarousel.carousel.heightAnchor.constraint(equalToConstant: 275)])

        // apply the constraints
        NSLayoutConstraint.activate(constraints, translatesAutoresizingMaskIntoConstraints: false)
    }

    func refreshLocation() {
        if (CLLocationManager.hasLocationPermissionAndEnabled()) {
            locationManager.requestLocation()
        } else {
            // requestLocation expected to be called on authorization status change.
            locationManager.maybeRequestLocationPermission(viewController: self)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    var once = false
}

extension PlaceCarouselViewController: MKMapViewDelegate {
    func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: Error) {
        // TODO: handle.
        print("lol-map \(error.localizedDescription)")
    }
}

extension PlaceCarouselViewController: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        refreshLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Use last coord: we want to display where the user is now.
        if let coord = locations.last?.coordinate {
            // Offset center to display user's location below place cards.
            let center = CLLocationCoordinate2D(latitude: coord.latitude + MAP_LATITUDE_OFFSET, longitude: coord.longitude)
            let span = MKCoordinateSpan(latitudeDelta: MAP_SPAN_DELTA, longitudeDelta: 0.0)
            mapView.region = MKCoordinateRegion(center: center, span: span)

            // Make sure we only call this once, for testing purposes.
            if !once {
                FirebasePlacesDatabase().getPlaces(forLocation: TEST_LL) { places in
                    self.placeCarousel.places = places
                }
                once = true
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // TODO: handle
        print("lol-location \(error.localizedDescription)")
    }
}
