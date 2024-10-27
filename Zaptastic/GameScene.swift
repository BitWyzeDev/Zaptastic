//
//  GameScene.swift
//  Zaptastic
//
//  Created by Scott Richards on 10/14/24.
//

import SpriteKit
import GameplayKit
import CoreMotion

enum CollisionType: UInt32 {
    case player = 1
    case playerWeapon = 2
    case enemy = 4
    case enemyWeapon = 8
}

class GameScene: SKScene {
    let player = SKSpriteNode(imageNamed: "player")
    let motionManager = CMMotionManager()

    let waves = Bundle.main.decode([Wave].self, from: "waves.json")
    let enemyTypes = Bundle.main.decode([EnemyType].self, from: "enemy-types.json")
    
    var isPlayerAlive = true
    var levelNumber = 0
    var waveNumber = 0
    
    let positions = Array(stride(from: -320, through: 320, by: 80))
    
    var playerShields = 10
    
    // Screen height & width
    var screenHeight: CGFloat = 0.0
    var screenWidth: CGFloat = 0.0
    
    // Constants for tilt range
    let minTilt: Double = 20.0 // 20 degrees
    let maxTilt: Double = 70.0 // 70 degrees

    var gameOverSprite: SKSpriteNode?
    var tapOnGameOverGestureRecognizer: UITapGestureRecognizer?
    
    override func didMove(to view: SKView) {
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        
        if let particles = SKEmitterNode(fileNamed: "Starfield") {
            particles.position = CGPoint(x: 1080, y: 0)
            particles.advanceSimulationTime(60)
            particles.zPosition = -1
            addChild(particles)
        }
        // Set the screen height (landscape orientation)
        screenHeight = self.size.height
        screenWidth = self.size.width
        debugPrint("screen width: \(screenWidth) height: \(screenHeight)")

        player.name = "player"
        player.position.x = frame.minX + player.texture!.size().width + 10
        debugPrint("player.position.x = \(player.position.x)")

        debugPrint("player.position.y = \(frame.midY)")
        player.position.y = frame.midY
        player.zPosition = 1
        addChild(player)
        debugPrint("player.texture!.size: \(player.texture!.size())")
        player.physicsBody = SKPhysicsBody(texture: player.texture!, size: player.texture!.size())
        player.physicsBody?.categoryBitMask = CollisionType.player.rawValue
        player.physicsBody?.collisionBitMask = CollisionType.enemy.rawValue | CollisionType.enemyWeapon.rawValue
        player.physicsBody?.contactTestBitMask = CollisionType.enemy.rawValue | CollisionType.enemyWeapon.rawValue
        player.physicsBody?.isDynamic = false
        // Get Accelerometer Updates to handle moving up and down
//        motionManager.startAccelerometerUpdates()
//        if motionManager.isDeviceMotionAvailable {
//            motionManager.deviceMotionUpdateInterval = 0.1
//            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
//                guard let self = self, let motionData = motion else { return }
//
//                // Get the pitch angle in degrees
//                debugPrint("motionData.attitude.pitch: \(motionData.attitude.pitch)")
//                let pitchInDegrees = motionData.attitude.roll * 180 / .pi
//                debugPrint("pitch in degrees: \(pitchInDegrees)")
//                // Update the sprite position based on the tilt angle
//                self.updateSpritePosition(for: pitchInDegrees)
//            }
//        }

        // Create and add a tap gesture recognizer

//        startGamePlay(view: view)
    }
    
    func startGamePlay(view: SKView) {
        addChild(player)
 
        motionManager.startAccelerometerUpdates()
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.1
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
                guard let self = self, let motionData = motion else { return }

                // Get the pitch angle in degrees
                debugPrint("motionData.attitude.pitch: \(motionData.attitude.pitch)")
                let pitchInDegrees = motionData.attitude.roll * 180 / .pi
                debugPrint("pitch in degrees: \(pitchInDegrees)")
                // Update the sprite position based on the tilt angle
                self.updateSpritePosition(for: pitchInDegrees)
            }
        }
        if let tapToFire = tapToFireGestureRecognizer {
            view.addGestureRecognizer(tapToFire)
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        for child in children {
            if child.frame.maxX < 0 {
                if !frame.intersects(child.frame) {
                    child.removeFromParent()
                }
            }
        }
        
        let activeEnemies = children.compactMap { $0 as? EnemyNode}
//        debugPrint(" # activeEnemies: \(activeEnemies.count)")
        
        if activeEnemies.isEmpty {
            createWave()
        }
        
        for enemy in activeEnemies {
            guard frame.intersects(enemy.frame) else { continue }
            if enemy.lastFireTime + 1 < currentTime {
                enemy.lastFireTime = currentTime
                if Int.random(in: 0...6) == 0 {
                    enemy.fire()
                }
            }
        }
    }
    
    // Function to map tilt angle to vertical position of the sprite
       func updateSpritePosition(for pitch: Double) {
//           // Clamp the pitch to the defined range
           let clampedPitch = min(max(pitch, minTilt), maxTilt)
           debugPrint("clampedPitch = \(clampedPitch)")
           
           // Normalize the pitch value between 0.0 and 1.0
           let normalizedPitch = (clampedPitch - minTilt) / (maxTilt - minTilt)
           debugPrint("normalizedPitch: \(normalizedPitch)")

           // Map the normalized pitch to the screen height (from bottom to top)
           let newYPosition = CGFloat(normalizedPitch) * screenHeight
           debugPrint("newYPosition: \(newYPosition)")

           // Move the sprite vertically
           player.position = CGPoint(x: player.position.x, y: newYPosition)
       }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isPlayerAlive else { return }
        
        let shot = SKSpriteNode(imageNamed: "playerWeapon")
        shot.name = "playerWeapon"
        shot.position = player.position
        
        shot.physicsBody = SKPhysicsBody(rectangleOf: shot.size)
        shot.physicsBody?.categoryBitMask = CollisionType.playerWeapon.rawValue
        shot.physicsBody?.collisionBitMask = CollisionType.enemy.rawValue | CollisionType.enemyWeapon.rawValue
        shot.physicsBody?.contactTestBitMask = CollisionType.enemy.rawValue | CollisionType.enemyWeapon.rawValue
        addChild(shot)

        let movement = SKAction.move(to: CGPoint(x: 1900, y: shot.position.y), duration: 10)
        let sequence = SKAction.sequence([movement, .removeFromParent()])
        shot.run(sequence)
    }
    
    func createWave() {
        guard isPlayerAlive else {
            return
        }
        
        if waveNumber == waves.count {
            levelNumber += 1
            waveNumber = 0
        }
        
        let currentWave = waves[waveNumber]
        waveNumber += 1
        
        let maximumEnemyType = min(enemyTypes.count, levelNumber + 1)
        let enemyType = Int.random(in: 0..<maximumEnemyType)
        
        let enemyOffsetX: CGFloat = 100
        let enemyStartX = 600
        
        if currentWave.enemies.isEmpty {
            for (index, position) in positions.shuffled().enumerated() {
                let enemy = EnemyNode(type: enemyTypes[enemyType], startPosition: CGPoint(x: enemyStartX, y: position), xOffset: enemyOffsetX * CGFloat(index * 3), moveStraight: true)
                addChild(enemy)
            }
        } else {
            for enemy in currentWave.enemies {
                let node = EnemyNode(type: enemyTypes[enemyType], startPosition: CGPoint(x: enemyStartX, y: positions[enemy.position]), xOffset: enemyOffsetX * enemy.xOffset, moveStraight: enemy.moveStraight)
                addChild(node)
            }
        }
    }
    
}


extension GameScene: SKPhysicsContactDelegate {
    func didBegin(_ contact: SKPhysicsContact) {
        guard let nodeA = contact.bodyA.node else { return }
        guard let nodeB = contact.bodyB.node else { return }
        
        let sortedNodes = [nodeA, nodeB].sorted { $0.name ?? "" < $1.name ?? "" }
        let firstNode = sortedNodes[0]
        let secondNode = sortedNodes[1]
        
        if secondNode.name == "player" {
            guard isPlayerAlive else { return }
            
            if let explosion = SKEmitterNode(fileNamed: "Explosion") {
                explosion.position = firstNode.position
                addChild(explosion)
            }
            
            playerShields -= 1
            
            // player is dead
            if playerShields == 0 {
                gameOver()
                secondNode.removeFromParent()
            }
            
            firstNode.removeFromParent()
        } else if let enemy = firstNode as? EnemyNode {
            enemy.shields -= 1
            
            // Enemy is dead
            if enemy.shields == 0 {
                if let explosion = SKEmitterNode(fileNamed: "Explosion") {
                    explosion.position = enemy.position
                    addChild(explosion)
                }
                enemy.removeFromParent()
            }
            
            // Enemy took a hit
            if let explosion = SKEmitterNode(fileNamed: "Explosion") {
                explosion.position = enemy.position
                addChild(explosion)
            }
            
            secondNode.removeFromParent()
        } else {
            if let explosion = SKEmitterNode(fileNamed: "Explosion") {
                explosion.position = secondNode.position
                addChild(explosion)
            }
            firstNode.removeFromParent()
            secondNode.removeFromParent()
        }
    }
    
    func gameOver() {
        isPlayerAlive = false
        player.removeFromParent()
        if let explosion = SKEmitterNode(fileNamed: "Explosion") {
            explosion.position = player.position
            addChild(explosion)
        }
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleGameOverTap(_:)))
        self.tapOnGameOverGestureRecognizer = tapGesture
        self.view?.addGestureRecognizer(tapGesture)
        let gameOver = SKSpriteNode(imageNamed: "gameOver")
        gameOver.name = "gameOver"
        gameOverSprite = gameOver
        addChild(gameOver)
    }
    
    @objc func handleGameOverTap(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: self.view) // Get tap location in the SKView
        let convertedLocation = convertPoint(fromView: location) // Convert to scene coordinates
        
        let nodesTapped = nodes(at: convertedLocation) // Get all nodes at the tapped location
        
        // Check if the SKSpriteNode was tapped
        for node in nodesTapped {
            if node.name == "gameOver" {
                print("Game Over node tapped!")
                // Perform actions for your sprite node here
                
            }
        }
        startNewGame()
    }
    
    func startNewGame() {
        self.view?.removeGestureRecognizer(tapOnGameOverGestureRecognizer)
        self.gameOverSprite?.removeFromParent()
    }
}
