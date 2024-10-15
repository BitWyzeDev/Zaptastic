//
//  EnemyType.swift
//  Zaptastic
//
//  Created by Scott Richards on 10/14/24.
//

import SpriteKit

struct EnemyType: Codable {
    let name: String
    let shields: Int
    let speed: CGFloat
    let powerUpChance: Int
}
