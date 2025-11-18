import SwiftUI

/// Shared helpers for fish path generation, orientation, and sizing.
enum FishAnimationUtils {
    static func randomForLoop(_ loopIndex: Int, seed: Double) -> Double {
        let x = sin(Double(loopIndex) * 12.9898 + seed) * 43758.5453
        return x - floor(x)
    }

    static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        return a + (b - a) * t
    }

    static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        return a + (b - a) * t
    }

    static func wormPath(taskIndex: Int, totalTasks: Int, letterX: CGFloat, in size: CGSize) -> CGFloat {
        let safeTotal = max(totalTasks, 1)
        let topBandHeight = size.height * 0.2 // Increased from 0.05 to 0.2 for more visible priority spread
        let baselineY = topBandHeight * (CGFloat(taskIndex) + 0.5) / CGFloat(safeTotal)
        let wormAmplitude = lerp(5, 10, randomForLoop(taskIndex, seed: 4.0))
        let wormFrequency = lerp(10, 20, randomForLoop(taskIndex, seed: 5.0))
        let wormPhase = lerp(0, 2 * Double.pi, randomForLoop(taskIndex, seed: 6.0))
        let secondaryAmplitude = lerp(1.0, 3.0, randomForLoop(taskIndex, seed: 7.0))
        let secondaryFrequency = lerp(1.0, 2.0, randomForLoop(taskIndex, seed: 8.0))
        let secondaryPhase = lerp(0, 2 * Double.pi, randomForLoop(taskIndex, seed: 9.0))
        let normalizedX = Double(letterX + size.width) / Double(size.width + size.width)
        let mod1 = wormAmplitude * sin(2 * .pi * wormFrequency * normalizedX + wormPhase)
        let mod2 = secondaryAmplitude * sin(2 * .pi * secondaryFrequency * normalizedX + secondaryPhase)
        return baselineY + CGFloat(mod1 + mod2)
    }

    static func tangentAngle(taskIndex: Int, totalTasks: Int, at x: CGFloat, in size: CGSize) -> Angle {
        let dx: CGFloat = 1.0
        let y1 = wormPath(taskIndex: taskIndex, totalTasks: totalTasks, letterX: x, in: size)
        let y2 = wormPath(taskIndex: taskIndex, totalTasks: totalTasks, letterX: x + dx, in: size)
        let angleRadians = atan2(y2 - y1, dx)
        return Angle(radians: Double(angleRadians))
    }

    static func letterScale(for index: Int, total: Int) -> CGFloat {
        guard total > 1 else { return 1.0 }
        let norm = CGFloat(index) / CGFloat(total - 1)
        let pectoralNorm: CGFloat = 0.1
        let ventralNorm: CGFloat = 0.3
        if norm <= pectoralNorm {
            return 1.0 + 0.1 * (norm / pectoralNorm)
        } else if norm <= ventralNorm {
            let factor = (norm - pectoralNorm) / (ventralNorm - pectoralNorm)
            return 1.1 - 0.2 * factor
        } else {
            let factor = (norm - ventralNorm) / (1 - ventralNorm)
            return 0.9 - 0.4 * factor
        }
    }
}
