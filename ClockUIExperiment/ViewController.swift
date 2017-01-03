//
//  ViewController.swift
//  ClockUIExperiment
//
//  Created by Mateusz Malczak on 03/01/17.
//  Copyright © 2017 The Pirate Cat. All rights reserved.
//
//  http://thepirate.cat
//

// Inspired by https://dribbble.com/shots/2946609-clock
// UI Experiment - check https://youtu.be/3rTBzhEieYE

import UIKit
import QuartzCore
import CoreGraphics

class ViewController: UIViewController {
    static var R = CGFloat(60.0)
    
    var lastTouch = CGPoint()

    var circleRadius = R
    var circlePosition = CGPoint()
    
    var fieldBounds = CGRect()
    
    var circleShape = CAShapeLayer()
    
    var fieldShape = CAShapeLayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        circlePosition = CGPoint(x: view.bounds.width * 0.5, y: 0)
        fieldBounds = CGRect(x: 0, y: 200, width: view.bounds.width, height: view.bounds.height - 200)
        
        createCircleShape()
        createFieldShape()
        
        view.layer.addSublayer(fieldShape)
        view.layer.addSublayer(circleShape)
        
        circleShape.position = circlePosition
    }
    
    func createCircleShape() {
        let bounds =  CGRect(x: 0, y: 0, width: ViewController.R * 2.0, height: ViewController.R * 2.0)
        circleShape.bounds = bounds
        circleShape.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        circleShape.path = UIBezierPath(ovalIn: bounds).cgPath
        circleShape.fillColor = UIColor.red.cgColor
    }
    
    func createFieldShape() {
        let bounds = fieldBounds.offsetBy(dx: 0, dy: -200)
        fieldShape.bounds = bounds;
        fieldShape.anchorPoint = CGPoint(x: 0, y: 0)
        fieldShape.path = UIBezierPath(rect: bounds).cgPath
        fieldShape.fillColor = UIColor.blue.cgColor
        fieldShape.position = fieldBounds.origin
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            lastTouch = touch.location(in: view)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let location = touch.location(in: view)
            circlePosition.y += (location.y - lastTouch.y)
            
            CATransaction.begin()
            CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
            circleShape.position = circlePosition
            CATransaction.commit()
            lastTouch = location

            detectIntersection()
        }
    }
    
    func detectIntersection() {
        let r = circleRadius
        let d = r * r - pow(fieldBounds.origin.y - circlePosition.y, 2);
        if d < 0.0 {
            updateFieldShape(intersections: [])
            return
        }
        
        let sqrtd = sqrt(d)
        let x0 = circlePosition.x - sqrtd
        let x1 = circlePosition.x + sqrtd
        
        updateFieldShape(intersections: [x0, x1])
    }
    
    func updateFieldShape(intersections:[CGFloat]) {
        let bounds = fieldBounds.offsetBy(dx: 0, dy: -200)
        
        if intersections.count == 0 {
            fieldShape.path = UIBezierPath(rect: bounds).cgPath
        }
        
        if intersections.count == 2 {
            let degToRad = CGFloat(M_PI) / 180.0
            let Pt: (_ x:CGFloat, _ y:CGFloat) -> CGPoint = { return CGPoint(x: $0, y: $1) }
            
            // effective radius to interact with area
            let effectiveRadius = circleRadius + 4.0
            // X-axis intersection lengt
            let intersectionSize = min(2 * effectiveRadius,(intersections[1] - intersections[0]) * 0.4)
            let center = CGPoint(x: circlePosition.x, y: circlePosition.y - fieldBounds.origin.y)
            
            // intersection angles
            var startAngle = atan2(fieldBounds.origin.y - circlePosition.y, intersections[0] - center.x)
            var endAngle = atan2(fieldBounds.origin.y - circlePosition.y, intersections[1] - center.x)

            // modify angle to make a smoother edges
            let dAngle = 25.0 * degToRad
            if abs(startAngle - endAngle) > 2.0 * dAngle {
                startAngle -= dAngle
                endAngle += dAngle
            }
            
            let startAnglePoint = Pt(effectiveRadius * cos(startAngle), effectiveRadius * sin(startAngle))
            let startAngleTangent = Pt(startAnglePoint.y, -startAnglePoint.x).normalized(-0.33 * intersectionSize)
            
            let heightOffset = intersectionSize * 0.2
            let pathInitPoint = Pt(bounds.minX, bounds.minY - heightOffset)
            let intersectionPoint = Pt(intersections[0] - intersectionSize, 0)
            let initVector = Pt(intersectionPoint.x - pathInitPoint.x,
                               intersectionPoint.y - pathInitPoint.y).normalized(heightOffset * 0.5)
            let initCtrlPoint = Pt((pathInitPoint.x + intersectionPoint.x)*0.5 - initVector.y,
                                  (pathInitPoint.y + intersectionPoint.y)*0.5 + initVector.x)
            
            let subPathPoints = [
                pathInitPoint, // initial move(to:)
                intersectionPoint, initCtrlPoint, // initial declination addQuadCurve(to: controlPoint:)
                startAnglePoint.offset(center), Pt(intersections[0] - intersectionSize * 0.33, 0), startAnglePoint.offset(center).offset(startAngleTangent) // pre ball rounding addCurve(to: controlPoint1: controlPoint2:)
            ]

            // mirror path fragment on right side
            var transform = CGAffineTransform.identity
            transform = transform.translatedBy(x: center.x, y: 0.0)
            transform = transform.scaledBy(x: -1.0, y: 1.0)
            transform = transform.translatedBy(x: -center.x, y: 0.0)
            
            let subPath2Point = subPathPoints.map { return $0.applying(transform) }

            let b = UIBezierPath()

            // left side path
            b.move(to: subPathPoints[0])
            b.addQuadCurve(to: subPathPoints[1],
                           controlPoint: subPathPoints[2])
            b.addCurve(to: subPathPoints[3],
                       controlPoint1: subPathPoints[4],
                       controlPoint2: subPathPoints[5])
            
            // bottom arc
            b.addArc(withCenter: center, radius: effectiveRadius, startAngle: startAngle, endAngle: endAngle, clockwise: false)

            // right side path
            b.addCurve(to: subPath2Point[1],
                       controlPoint1: subPath2Point[5],
                       controlPoint2: subPath2Point[4])
            b.addQuadCurve(to: subPath2Point[0],
                           controlPoint: subPath2Point[2])
            
            
            // close path from bottom
            b.addLine(to: Pt(bounds.maxX, bounds.minY))
            b.addLine(to: Pt(bounds.maxX, bounds.maxY))
            b.addLine(to: Pt(bounds.minX, bounds.maxY))
            b.close()

            fieldShape.path = b.cgPath
        }
    }

}

extension CGPoint {
    func offset(_ point:CGPoint) -> CGPoint {
        return CGPoint(x: x + point.x, y: y + point.y)
    }
    
    func normalized(_ size:CGFloat) -> CGPoint {
        let length = sqrt(x*x + y*y)
        return CGPoint(x: size*x/length, y: size*y/length)
    }
    
    func nagate() -> CGPoint {
        return CGPoint(x: -x, y: -y)
    }
}
