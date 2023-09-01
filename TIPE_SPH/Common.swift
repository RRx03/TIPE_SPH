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
    static var particleCount : Int32 = 1000
    static var h : Float = 1
    static var Volume : Float = 1
    static var radius : Float = 0.01
    static var meshPrecision : UInt32 = 10
    static var spawnJigger : Float = 0.2
    static var gridSize : [Float] = [1, 1, 1] //c'est la taille de chaque cote du centre donc on double pour avoir la vraie width, height, depth
    static var gridCenterPosition : [Float] = [0, 2, 0]


}

