//
//  PoseLandmark.swift
//  SprintTimer
//
//  Created by Matthew Tybur on 11/19/24.
//

import Foundation

struct PoseLandmark {
    static let connections: [Connection] = [
        // Upper Body
        Connection(startIndex: 0, endIndex: 1),   // Nose to Left Eye Inner
        Connection(startIndex: 0, endIndex: 4),   // Nose to Right Eye Inner
        Connection(startIndex: 1, endIndex: 2),   // Left Eye Inner to Left Eye
        Connection(startIndex: 2, endIndex: 3),   // Left Eye to Left Eye Outer
        Connection(startIndex: 3, endIndex: 7),   // Left Eye Outer to Left Ear
        Connection(startIndex: 4, endIndex: 5),   // Right Eye Inner to Right Eye
        Connection(startIndex: 5, endIndex: 6),   // Right Eye to Right Eye Outer
        Connection(startIndex: 6, endIndex: 8),   // Right Eye Outer to Right Ear
        Connection(startIndex: 9, endIndex: 10),  // Mouth Left to Mouth Right
        Connection(startIndex: 11, endIndex: 12), // Left Shoulder to Right Shoulder

        // Left Arm
        Connection(startIndex: 11, endIndex: 13), // Left Shoulder to Left Elbow
        Connection(startIndex: 13, endIndex: 15), // Left Elbow to Left Wrist
        Connection(startIndex: 15, endIndex: 17), // Left Wrist to Left Pinky
        Connection(startIndex: 15, endIndex: 19), // Left Wrist to Left Index
        Connection(startIndex: 15, endIndex: 21), // Left Wrist to Left Thumb
        Connection(startIndex: 17, endIndex: 19), // Left Pinky to Left Index

        // Right Arm
        Connection(startIndex: 12, endIndex: 14), // Right Shoulder to Right Elbow
        Connection(startIndex: 14, endIndex: 16), // Right Elbow to Right Wrist
        Connection(startIndex: 16, endIndex: 18), // Right Wrist to Right Pinky
        Connection(startIndex: 16, endIndex: 20), // Right Wrist to Right Index
        Connection(startIndex: 16, endIndex: 22), // Right Wrist to Right Thumb
        Connection(startIndex: 18, endIndex: 20), // Right Pinky to Right Index

        // Torso
        Connection(startIndex: 11, endIndex: 23), // Left Shoulder to Left Hip
        Connection(startIndex: 12, endIndex: 24), // Right Shoulder to Right Hip
        Connection(startIndex: 23, endIndex: 24), // Left Hip to Right Hip

        // Left Leg
        Connection(startIndex: 23, endIndex: 25), // Left Hip to Left Knee
        Connection(startIndex: 25, endIndex: 27), // Left Knee to Left Ankle
        Connection(startIndex: 27, endIndex: 29), // Left Ankle to Left Heel
        Connection(startIndex: 29, endIndex: 31), // Left Heel to Left Foot Index
        Connection(startIndex: 27, endIndex: 31), // Left Ankle to Left Foot Index

        // Right Leg
        Connection(startIndex: 24, endIndex: 26), // Right Hip to Right Knee
        Connection(startIndex: 26, endIndex: 28), // Right Knee to Right Ankle
        Connection(startIndex: 28, endIndex: 30), // Right Ankle to Right Heel
        Connection(startIndex: 30, endIndex: 32), // Right Heel to Right Foot Index
        Connection(startIndex: 28, endIndex: 32), // Right Ankle to Right Foot Index
    ]

    struct Connection {
        let startIndex: Int
        let endIndex: Int
    }
}
