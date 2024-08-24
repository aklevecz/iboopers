//
//  Egg.swift
//  iboopers
//
//  Created by Ariel Klevecz on 8/4/24.
//

import Foundation
import SwiftUI
import CoreLocation

struct Egg: Hashable, Codable, Identifiable {
    var id: String
    var name: String
    var description: String
    var isFound: Bool
}
