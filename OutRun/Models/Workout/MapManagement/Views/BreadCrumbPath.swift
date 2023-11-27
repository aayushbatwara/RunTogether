//
//  BreadCrumbPath
//Abstract:
//A overlay model object representing a path that changes over time.
//*/

import Foundation
import MapKit
import os

// - Tag: overlay_threads
class BreadcrumbPath: NSObject, MKOverlay {
    private(set) var coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)

    var boundingMapRect: MKMapRect
    
    var locations: [CLLocation]
    
    
    var bounds: MKMapRect
    
    init(locations: [CLLocation], pathBounds: MKMapRect = MKMapRect.world) {
        self.locations = locations
        self.bounds = pathBounds
//        self.coordinate = locations.first!.coordinate   //this could be an error if locations array is empty
        self.boundingMapRect = MKMapRect.world
        
    }
    

}
