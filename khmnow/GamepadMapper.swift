import Foundation

public struct GamepadMapper {
    public static func mapButtons(
        buttonA: Float,
        buttonB: Float,
        buttonX: Float,
        buttonY: Float,
        leftShoulder: Float,
        rightShoulder: Float,
        leftTrigger: Float,
        rightTrigger: Float,
        buttonSelect: Float,
        buttonStart: Float,
        buttonL3: Float,
        buttonR3: Float,
        dpadUp: Float,
        dpadDown: Float,
        dpadLeft: Float,
        dpadRight: Float
    ) -> [Double] {
        return [
            Double(buttonA),
            Double(buttonB),
            Double(buttonX),
            Double(buttonY),
            Double(leftShoulder),
            Double(rightShoulder),
            Double(leftTrigger),
            Double(rightTrigger),
            Double(buttonSelect),
            Double(buttonStart),
            Double(buttonL3),
            Double(buttonR3),
            Double(dpadUp),
            Double(dpadDown),
            Double(dpadLeft),
            Double(dpadRight)
        ]
    }
    
    public static func mapAxes(
        leftX: Float,
        leftY: Float,
        rightX: Float,
        rightY: Float
    ) -> [Double] {
        return [
            Double(leftX),
            Double(-leftY), // Negate for Web standard (up is negative)
            Double(rightX),
            Double(-rightY)  // Negate for Web standard (up is negative)
        ]
    }
}
