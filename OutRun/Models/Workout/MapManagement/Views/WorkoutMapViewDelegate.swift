//
//  WorkoutMapViewDelegate.swift
//
//  OutRun
//  Copyright (C) 2020 Tim Fraedrich <timfraedrich@icloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit
import MapKit

class WorkoutMapViewDelegate: NSObject, MKMapViewDelegate {
    
    static let standard = WorkoutMapViewDelegate()      //kind of a simgleton implementation
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: overlay)     //This is what renders the lines

        if (overlay.title == "accompanier"){
            renderer.strokeColor = UIColor.systemBlue
        }
        else{
            renderer.strokeColor = .accentColor
        }
        renderer.lineWidth = 8.0
                
        return renderer     //this returned MKOverlayRenderer has the overlay
    }
    
}
