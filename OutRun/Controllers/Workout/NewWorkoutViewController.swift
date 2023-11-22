//
//  NewWorkoutViewController.swift
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
import SnapKit
import SocketIO


class NewWorkoutViewController: MapViewControllerWithContainerView, WorkoutBuilderDelegate, UIGestureRecognizerDelegate {
    
    let manager = SocketManager(socketURL: URL(string: "http://10.68.76.197:3000/")!, config: [.log(true), .compress])
    var socket:SocketIOClient!

    var type: Workout.WorkoutType = Workout.WorkoutType(rawValue: UserPreferences.standardWorkoutType.value)
    lazy var builder: WorkoutBuilder = WorkoutBuilder(workoutType: self.type, delegate: self)
    var userMovedMap: Bool = false {
        didSet {    //property observer: when ever value of userMovedMap changes, the following code below executes
            DispatchQueue.main.async {      //this line makes sure UI updates below performed on main thread
                UIView.animate(withDuration: 0.25) {
                    self.recenterButton.isHidden = !self.userMovedMap
                }
            }
        }
    }
    
    let readinessIndicatorView = WorkoutBuilderReadinessIndicationView()
    lazy var typeView = FloatingButton(title: self.type.description) { (button) in
        let alert = WorkoutTypeAlert(
            action: { (type) in
                self.builder.workoutType = type
                button.setTitle(type.description.uppercased(), for: .normal)
            }
        )
        alert.present(on: self)
    }
    
    let distanceView: LabelledDataView = LabelledDataView(title: LS["Workout.Distance"], measurement: NSMeasurement(doubleValue: 0, unit: UnitLength.meters))
    
    let durationView: LabelledDataView = LabelledDataView(title: LS["Workout.Duration"], measurement: NSMeasurement(doubleValue: 0, unit: UnitDuration.seconds))
    
    let speedView: LabelledDataView = LabelledDataView(title: UserPreferences.displayRollingSpeed.value ? LS["Workout.AverageSpeed"] : LS["Workout.CurrentSpeed"], measurement: NSMeasurement(doubleValue: 0, unit: UnitSpeed.metersPerSecond))
    
    let paceView: LabelledRelativeDataView = LabelledRelativeDataView(title: UserPreferences.displayRollingSpeed.value ? LS["Workout.RollingPace"] : LS["Workout.TotalPace"], relativeMeasurement: RelativeMeasurement(value: 0, primaryUnit: UnitDuration.minutes, dividingUnit: UserPreferences.distanceMeasurementType.safeValue))
    
    let caloriesView: LabelledDataView = LabelledDataView(title: LS["Workout.BurnedCalories"], measurement: NSMeasurement(doubleValue: 0, unit: UnitEnergy.kilocalories))
    
    lazy var actionButton = NewWorkoutControllerActionButton { (button, actionType) in
        
        switch actionType {
        case .start:
            self.builder.startOrResume { (success) in
                if success {
                    print("[NewWorkout] started recording")
                } else {
                    self.displayBuilderFailureError()
                }
            }
        case .stop:
            self.builder.finish { (success) in
                if success {
                    print("[NewWorkout] finished recording")
                } else {
                    self.displayBuilderFailureError()
                }
            }
        case .pauseOrContinue:
            if self.builder.status == .paused {
                self.builder.startOrResume { (success) in
                    if success {
                        print("[NewWorkout] continued recording")
                    } else {
                        self.displayBuilderFailureError()
                    }
                }
            } else {
                self.builder.pause { (success) in
                    if success {
                        print("[NewWorkout] paused recording")
                    } else {
                        self.displayBuilderFailureError()
                    }
                }
            }
            
        }
    }
    
    lazy var recenterButton = FloatingButton(title: LS["NewWorkoutViewController.Recenter"]) { (button) in
        self.userMovedMap = false
        
        guard let location = self.builder.locationManagement.locations.last else {
            return
        }
        let camera = MKMapCamera(lookingAtCenter: location.coordinate, fromDistance: 200, pitch: 0, heading: location.course)
        self.mapView?.setCamera(camera, animated: true)
    }
    
    var routeOverlay: MKOverlay?
    
    var blurView = UIVisualEffectView(effect: UIBlurEffect(style: {
        if #available(iOS 13.0, *) {
            return .systemThinMaterial
        } else {
            return .extraLight
        }
    }()))
    
    override func viewDidLoad() {
        
        if !UserPreferences.shouldShowMap.value {
            
            self.mapView = nil
            
        }
        
        self.headline = LS["Workout.NewWorkout"]
        self.builder = WorkoutBuilder(workoutType: type, delegate: self)
        mapView?.delegate = WorkoutMapViewDelegate.standard     //kind of a simgleton implementation
        self.readinessIndicatorView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(displayIndicationAlert)))
        self.recenterButton.isHidden = true
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(userInteractedWithMap(_:)))
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(userInteractedWithMap(_:)))
        pan.delegate = self
        pinch.delegate = self
        self.mapView?.addGestureRecognizer(pan)
        self.mapView?.addGestureRecognizer(pinch)
        
        self.view.addSubview(blurView)
        blurView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        super.viewDidLoad()
        
        self.view.backgroundColor = .clear
        
        // MARK: adding views to superview
        self.view.addSubview(readinessIndicatorView)
        self.view.addSubview(typeView)
        self.view.addSubview(recenterButton)
        
        let speedIndication = UserPreferences.usePaceForSpeedDisplay.value ? paceView : speedView
        
        // MARK: adding views to statsView
        self.containerView.addSubview(distanceView)
        self.containerView.addSubview(durationView)
        self.containerView.addSubview(speedIndication)
        self.containerView.addSubview(caloriesView)
        self.containerView.addSubview(actionButton)
        
        // MARK: setting constraints
        let safeLayout = self.view.safeAreaLayoutGuide
        readinessIndicatorView.snp.makeConstraints { (make) in
            make.bottom.equalTo(containerView.snp.top).offset(-10)
            make.right.equalTo(safeLayout).offset(-10)
        }
        typeView.snp.makeConstraints { (make) in
            make.bottom.equalTo(containerView.snp.top).offset(-10)
            make.left.equalTo(safeLayout).offset(10)
        }
        recenterButton.snp.makeConstraints { (make) in
            make.bottom.equalTo(readinessIndicatorView.snp.top).offset(-10)
            make.right.equalTo(safeLayout).offset(-10)
        }
        
        let spacing: CGFloat = 20
        
        distanceView.snp.makeConstraints { (make) in
            make.top.equalTo(containerView.snp.top).offset(spacing)
            make.left.equalTo(containerView.snp.left).offset(spacing)
        }
        durationView.snp.makeConstraints { (make) in
            make.top.equalTo(containerView.snp.top).offset(spacing)
            make.left.equalTo(distanceView.snp.right).offset(spacing)
            make.right.equalTo(containerView.snp.right).offset(-spacing)
            make.width.equalTo(distanceView)
        }
        speedIndication.snp.makeConstraints { (make) in
            make.top.equalTo(distanceView.snp.bottom).offset(spacing)
            make.left.equalTo(containerView.snp.left).offset(spacing)
        }
        caloriesView.snp.makeConstraints { (make) in
            make.top.equalTo(durationView.snp.bottom).offset(spacing)
            make.left.equalTo(speedIndication.snp.right).offset(spacing)
            make.right.equalTo(containerView.snp.right).offset(-spacing)
            make.width.equalTo(speedIndication)
        }
        actionButton.snp.makeConstraints { (make) in
            make.top.equalTo(speedIndication.snp.bottom).offset(spacing)
            make.left.equalTo(containerView.snp.left).offset(spacing)
            make.right.equalTo(containerView.snp.right).offset(-spacing)
            make.bottom.equalTo(safeLayout).offset(-spacing)
            make.height.equalTo(50)
        }
        

        socket = manager.defaultSocket

        socket.on(clientEvent: .connect) {data, ack in
            print("socket connected")
        }

        socket.on(clientEvent: .disconnect) {data, ack in
            print("socket disconnected")
        }
        socket.connect()
        
//        socket.on("eventName") { data, ack in
//            if let eventResponse = data.first as? [String: Any] {
//                // Handle the event response data
//            }
//        }

    }
    
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        if self.presentedViewController == nil {
            self.builder.actOnDismiss()
        }
        super.dismiss(animated: flag, completion: completion)
    }
    
    func didUpdate(distanceMeasurement: NSMeasurement) {
        self.distanceView.value = distanceMeasurement
    }
    
    func didUpdate(durationMeasurement: NSMeasurement) {
        self.durationView.value = durationMeasurement
    }
    
    func didUpdate(speedMeasurement: NSMeasurement, rolling: Bool) {
        self.speedView.value = speedMeasurement
    }
    
    func didUpdate(energyMeasurement: NSMeasurement) {
        self.caloriesView.value = energyMeasurement
    }
    
    func didUpdate(paceMeasurement: RelativeMeasurement, rolling: Bool) {
        self.paceView.value = paceMeasurement
    }
    
    func didUpdate(status: WorkoutBuilder.Status) {
        self.readinessIndicatorView.status = status
        self.actionButton.transition(to: status)
        
        if #available(iOS 13.0, *) {
            if status.isActiveStatus {
                self.isModalInPresentation = true
            } else {
                self.isModalInPresentation = false
            }
        }
    }
    // this function resets the camera view to to make sure user's new position is at center
    // add feature: publish current location to server / socket
    func didUpdate(currentLocation location: CLLocation, force: Bool) {
        //Changing view
        if !userMovedMap {  //why only if user doesnt move map? what happens when user moves map?
            let camera = MKMapCamera(lookingAtCenter: location.coordinate, fromDistance: 200, pitch: 0, heading: location.course)
            self.mapView?.setCamera(camera, animated: !force)   //setting the map view
        }
        
        // Publishing Result
        print("Publishing current location")
        socket.emit("location", "phone", location.coordinate.latitude, location.coordinate.longitude)
        
        
    }
    // i think this function adds the lines which correspond to user's route……but the breakpoint was never triggered??
    func didUpdate(routeData: [CLLocation]) { //argument is array of CLLocation
        let coordinates = routeData.map { (location) -> CLLocationCoordinate2D in   //return coordinates of CLLocation
            return location.coordinate
        }
        let overlayReference = routeOverlay     //what is route overlay
        self.routeOverlay = MKPolyline(coordinates: coordinates, count: routeData.count)    //indicates route defined by coordinates
        self.mapView?.addOverlay(routeOverlay!, level: .aboveRoads)     //add to mapview
        if let overlay = overlayReference {     //removes the previous overlay if it was defined. skipped in first go but not in subsequent ones
            self.mapView?.removeOverlay(overlay)
        }
    }
//breakpoints hitting even when route lines not generated……figure out
    
    func didUpdate(uiUpdatesSuspended: Bool) {
        if uiUpdatesSuspended {
            mapView?.removeFromSuperview()
        } else if let mapView = self.mapView, !view.subviews.contains(mapView) {
            self.addMapViewWithConstraints()
        }
    }
    
    func didInformOfInsufficientLocationPermission() {
        self.displayOpenSettingsAlert(
            withTitle: LS["Error"],
            message: LS["Setup.Permission.Location.Error"]
        )
    }
    
    @objc func displayIndicationAlert() {
        if self.readinessIndicatorView.status == .waiting {
            let alert = UIAlertController(
                title: LS["NewWorkoutViewController.WaitingAlert.Title"],
                message: LS["NewWorkoutViewController.WaitingAlert.Message"],
                preferredStyle: .alert,
                options: [
                    (
                        title: LS["Okay"],
                        style: .default,
                        action: nil
                    )
                ]
            )
            self.present(alert, animated: true)
        }
    }
    
    @objc override func close() {
        
        if builder.status.isActiveStatus {
            
            var alert: UIAlertController?
            alert = UIAlertController(
                title: LS["NewWorkoutViewController.Cancel.Error.Recording.Title"],
                message: LS["NewWorkoutViewController.Cancel.Error.Recording.Message"],
                preferredStyle: .alert,
                options: [
                    (
                        title: LS["NewWorkoutViewController.Cancel.Error.Recording.Action.StopRecording"],
                        style: .destructive,
                        action: { _ in
                            self.builder.finish(shouldProvideCompletionActions: false) { (success) in
                                if success {
                                    alert?.dismiss(animated: true) {
                                        self.dismiss(animated: true) {
                                            print("[NewWorkout] dismissed after saving")
                                        }
                                    }
                                } else {
                                    self.displayBuilderFailureError()
                                    print("[NewWorkout] stop tracking failed")
                                }
                            }
                        }
                    ),
                    (
                        title: LS["Continue"],
                        style: .cancel,
                        action: nil
                    )
                ]
            )
            self.present(alert!, animated: true)
            
        } else {
            self.dismiss(animated: true) {
                print("[NewWorkout] dismissed")
            }
        }
    }
    
    override func addMapViewWithConstraints() {
        super.addMapViewWithConstraints()
        self.view.sendSubviewToBack(blurView)
    }
    
    func displayBuilderFailureError() {
        DispatchQueue.main.async {
            self.displayError(withMessage: LS["NewWorkoutViewController.WorkoutBuilder.Error"]
            )
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    @objc func userInteractedWithMap(_ recognizer: UIGestureRecognizer) {
        if recognizer.state == .ended {
            self.userMovedMap = true
        }
    }
    
}
