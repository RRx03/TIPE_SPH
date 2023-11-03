//
//  Common.swift
//  TIPE_SPH
//
//  Created by Roman Roux on 31/08/2023.
//

import Foundation
import simd

enum Settings{

    static var PreferredFrameRate : Int = 60
    static var debugMode : Bool = false
    static var width : CGFloat = 1300
    static var height : CGFloat = 1000
    static var fov : Float = 70
    static var nearPlan : Float = 0.1
    static var farPlan : Float = 100
    static var fixedDeltaTime : Float = 0
    static var gravity : Float = 9.81
    static var cameraPosition : SIMD3<Float> = [0, 5, -20]
    static var cameraAngle : Float = -Float.pi/10
    static var globalFriction : Float = 1



}

enum ParticleSettings{

    static var h : Float = 0.1
    static var radius : Float = 0.1
    static var Volume : Float = 1
    static var meshPrecision : UInt32 = 10
    
    static var spawnJigger : Float = 0.1
    static var gridPopulation : [Int] = [10, 100, 10]
    static var gridSize : [Float] = [9, 6, 9]
    static var gridPosition : [Float] = [0.5, 4, 0]
    static var particleCount : Int32 {return Int32(gridPopulation[0]*gridPopulation[1]*gridPopulation[2])}
    
    static var containerPosition : [Float] = [0, 0, 0]
    static var containerSize : [Float] = [10, 10, 10]

    
    static var mass : Float = 1
    static var gazConstant : Float = 1
    static var restDensity : Float = 1
    static var bouncingCoefficient : Float = 1
    static var groundFrictionCoefficient : Float = 100
    
    static var gridding : [Float] = [10, 10, 10]

}

