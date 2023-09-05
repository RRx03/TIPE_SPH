//
//  Common.swift
//  TIPE_SPH
//
//  Created by Roman Roux on 31/08/2023.
//

import Foundation
import simd

enum Settings{
    static var width : CGFloat = 1000
    static var height : CGFloat = 1000
    static var fov : Float = 70
    static var nearPlan : Float = 0.1
    static var farPlan : Float = 100
 
    
}

enum ParticleSettings{
    static var h : Float = 0.01
    static var radius : Float = 0.01
    static var Volume : Float = 1
    static var meshPrecision : UInt32 = 10
    
    static var spawnJigger : Float = 0.1
    static var gridPopulation : [Int] = [10, 100, 10]
    static var gridSize : [Float] = [1, 3, 1]
    static var gridPosition : [Float] = [-0.5, 2, -0.5]
    static var particleCount : Int32 {return Int32(gridPopulation[0]*gridPopulation[1]*gridPopulation[2])}
    
    static var containerSize : [Float] = [2, 10, 2]
    static var containerPosition : [Float] = [-1, 0, -1]
    
    static var mass : Float = 1
    static var gazConstant : Float = 1
    static var restDensity : Float = 1
    static var bouncingCoefficient : Float = 0.5


}

