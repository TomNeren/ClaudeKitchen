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

    /// The parts of a setting in display order: program, temperature, rotation, time. Empty when nothing is set.
    /// Steam heat is left out when the steam program already says it.
    public static func parts(of setting: DeviceSetting) -> [String] {
        let heat = setting.program == .steam && setting.heat == .steam ? nil : setting.heat
        return [
            program(setting.program), heat.map(temperature), setting.rotation.map(rotation),
            setting.duration.map(duration),
        ]
        .compactMap(\.self)
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
