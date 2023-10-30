//
//  TIPE_SPHApp.swift
//  TIPE_SPH
//
//  Created by Roman Roux on 31/08/2023.
//

import SwiftUI

@main
struct TIPE_SPHApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView().frame(width: Settings.width, height: Settings.height, alignment: .center).fixedSize()
        }.windowResizability(.contentSize)
    }
}
