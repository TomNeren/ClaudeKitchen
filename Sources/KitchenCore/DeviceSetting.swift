import Foundation

/// How the pot is heated during a step.
public enum Heat: Sendable, Hashable {
    case celsius(Int)
    /// Steam mode. Temperature and speed are fixed by the device.
    case steam
}

/// Direction and speed of the blade.
public enum Rotation: Sendable, Hashable {
    case forward(speed: Int)
    /// Reverse rotation ("Linkslauf"): stirs gently with the blunt side of the blades.
    case reverse(speed: Int)

    public var speed: Int {
        switch self {
        case .forward(let speed), .reverse(let speed):
            return speed
        }
    }
}

/// A program the device offers besides manual mode.
public enum Program: String, Sendable, Hashable, Codable, CaseIterable {
    case manual
    case steam
    case knead
    case sousVide
    case yogurt
    case weigh
}

/// What the cook sets on the device for one step.
///
/// JSON shape: `{"program": "manual", "heat": 120, "speed": 1, "reverse": true, "seconds": 180}`.
/// `heat` is a number in °C or the string `"steam"`. Every key is optional; `program` defaults to `manual`.
public struct DeviceSetting: Sendable, Hashable {
    public var program: Program
    public var heat: Heat?
    public var rotation: Rotation?
    public var duration: Duration?

    public init(program: Program = .manual, heat: Heat? = nil, rotation: Rotation? = nil, duration: Duration? = nil) {
        self.program = program
        self.heat = heat
        self.rotation = rotation
        self.duration = duration
    }
}

extension DeviceSetting: Codable {
    private enum CodingKeys: String, CodingKey {
        case program, heat, speed, reverse, seconds
    }

    private static let steamValue = "steam"

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        program = try container.decodeIfPresent(Program.self, forKey: .program) ?? .manual

        if container.contains(.heat) {
            if let celsius = try? container.decode(Int.self, forKey: .heat) {
                heat = .celsius(celsius)
            } else if try container.decode(String.self, forKey: .heat) == Self.steamValue {
                heat = .steam
            } else {
                throw DecodingError.dataCorruptedError(
                    forKey: .heat, in: container, debugDescription: "heat must be a number in °C or \"steam\".")
            }
        } else {
            heat = nil
        }

        if let speed = try container.decodeIfPresent(Int.self, forKey: .speed) {
            let reverse = try container.decodeIfPresent(Bool.self, forKey: .reverse) ?? false
            rotation = reverse ? .reverse(speed: speed) : .forward(speed: speed)
        } else {
            rotation = nil
        }

        duration = try container.decodeIfPresent(Int.self, forKey: .seconds).map { .seconds($0) }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if program != .manual {
            try container.encode(program, forKey: .program)
        }
        switch heat {
        case .celsius(let celsius):
            try container.encode(celsius, forKey: .heat)
        case .steam:
            try container.encode(Self.steamValue, forKey: .heat)
        case nil:
            break
        }
        if let rotation {
            try container.encode(rotation.speed, forKey: .speed)
            if case .reverse = rotation {
                try container.encode(true, forKey: .reverse)
            }
        }
        if let duration {
            try container.encode(Int(duration.components.seconds), forKey: .seconds)
        }
    }
}
