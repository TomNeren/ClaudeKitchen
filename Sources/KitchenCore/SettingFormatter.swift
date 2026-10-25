import Foundation

/// Short German labels for device settings, as shown on the device console and in step overviews.
public enum SettingFormatter {
    public static func temperature(_ heat: Heat) -> String {
        switch heat {
        case .celsius(let celsius):
            return "\(celsius) °C"
        case .steam:
            return "Dampf"
        }
    }

    public static func rotation(_ rotation: Rotation) -> String {
        switch rotation {
        case .forward(let speed):
            return "Stufe \(speed)"
        case .reverse(let speed):
            return "Linkslauf \(speed)"
        }
    }

    /// "5 Sek", "3 Min", "1 Min 30 Sek".
    public static func duration(_ duration: Duration) -> String {
        let total = Int(duration.components.seconds)
        let minutes = total / 60
        let seconds = total % 60
        switch (minutes, seconds) {
        case (0, _):
            return "\(seconds) Sek"
        case (_, 0):
            return "\(minutes) Min"
        default:
            return "\(minutes) Min \(seconds) Sek"
        }
    }

    /// The name of a program, nil for manual mode.
    public static func program(_ program: Program) -> String? {
        switch program {
        case .manual: nil
        case .steam: "Dampfgaren"
        case .knead: "Kneten"
        case .sousVide: "Sous-vide"
        case .yogurt: "Joghurt"
        case .weigh: "Wiegen"
        }
    }

    /// One labelled value of a setting, as shown on a console tile.
    public struct Part: Sendable, Hashable {
        public enum Kind: Sendable, Hashable {
            case program, temperature, rotation, duration
        }

        public var kind: Kind
        /// Tile caption, for example "Linkslauf".
        public var label: String
        /// Value as shown on the tile, for example "1".
        public var value: String
        /// Label and value as one phrase, for example "Linkslauf 1".
        public var text: String
    }

    /// The labelled parts of a setting in display order: program, temperature, rotation, time.
    /// Steam heat is left out when the steam program already says it. Empty when nothing is set.
    public static func labeledParts(of setting: DeviceSetting) -> [Part] {
        var parts: [Part] = []
        if let name = program(setting.program) {
            parts.append(Part(kind: .program, label: "Programm", value: name, text: name))
        }
        if let heat = setting.heat, !(setting.program == .steam && heat == .steam) {
            let value = temperature(heat)
            parts.append(Part(kind: .temperature, label: "Temperatur", value: value, text: value))
        }
        if let rotation = setting.rotation {
            let label: String
            switch rotation {
            case .forward:
                label = "Stufe"
            case .reverse:
                label = "Linkslauf"
            }
            parts.append(Part(kind: .rotation, label: label, value: "\(rotation.speed)", text: self.rotation(rotation)))
        }
        if let duration = setting.duration {
            let value = self.duration(duration)
            parts.append(Part(kind: .duration, label: "Zeit", value: value, text: value))
        }
        return parts
    }

    /// The parts of a setting as phrases, for example `["100 °C", "Linkslauf 1", "20 Min"]`.
    public static func parts(of setting: DeviceSetting) -> [String] {
        labeledParts(of: setting).map(\.text)
    }

    /// The timer as a clock: "3:00", "0:05", "1:02:30".
    public static func clock(_ duration: Duration) -> String {
        let total = max(0, Int(duration.components.seconds) + (duration.components.attoseconds > 0 ? 1 : 0))
        let hours = total / 3600
        let minutes = total % 3600 / 60
        let seconds = total % 60
        let paddedSeconds = seconds < 10 ? "0\(seconds)" : "\(seconds)"
        guard hours > 0 else { return "\(minutes):\(paddedSeconds)" }
        let paddedMinutes = minutes < 10 ? "0\(minutes)" : "\(minutes)"
        return "\(hours):\(paddedMinutes):\(paddedSeconds)"
    }
}
