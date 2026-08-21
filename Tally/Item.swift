//
//  Item.swift
//  Tally
//
//  Created by . Xu on 2026/8/21.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
