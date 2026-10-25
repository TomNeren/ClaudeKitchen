import Testing

@testable import KitchenCore

@Suite("Setting formatting")
struct SettingFormatterTests {
    @Test func formatsEachPart() {
        #expect(SettingFormatter.temperature(.celsius(120)) == "120 °C")
        #expect(SettingFormatter.temperature(.steam) == "Dampf")
        #expect(SettingFormatter.rotation(.forward(speed: 5)) == "Stufe 5")
        #expect(SettingFormatter.rotation(.reverse(speed: 1)) == "Linkslauf 1")
    }

    @Test(arguments: [(5, "5 Sek"), (180, "3 Min"), (90, "1 Min 30 Sek"), (1200, "20 Min")])
    func formatsDurations(seconds: Int, expected: String) {
        #expect(SettingFormatter.duration(.seconds(seconds)) == expected)
    }

    @Test func listsPartsInDisplayOrder() {
        let setting = DeviceSetting(heat: .celsius(100), rotation: .reverse(speed: 1), duration: .seconds(1200))
        #expect(SettingFormatter.parts(of: setting) == ["100 °C", "Linkslauf 1", "20 Min"])
        #expect(SettingFormatter.parts(of: DeviceSetting()).isEmpty)
    }

    @Test func labelsPartsForConsoleTiles() {
        let setting = DeviceSetting(heat: .celsius(120), rotation: .reverse(speed: 1), duration: .seconds(180))
        let parts = SettingFormatter.labeledParts(of: setting)
        #expect(parts.map(\.kind) == [.temperature, .rotation, .duration])
        #expect(parts.map(\.label) == ["Temperatur", "Linkslauf", "Zeit"])
        #expect(parts.map(\.value) == ["120 °C", "1", "3 Min"])
        #expect(
            SettingFormatter.labeledParts(of: DeviceSetting(rotation: .forward(speed: 5))).map(\.label) == ["Stufe"])
    }

    @Test func namesNonManualPrograms() {
        let sousVide = DeviceSetting(program: .sousVide, heat: .celsius(60), duration: .seconds(3600))
        #expect(SettingFormatter.parts(of: sousVide) == ["Sous-vide", "60 °C", "60 Min"])
        let steam = DeviceSetting(program: .steam, heat: .steam, duration: .seconds(720))
        #expect(SettingFormatter.parts(of: steam) == ["Dampfgaren", "12 Min"])
        #expect(SettingFormatter.parts(of: DeviceSetting(heat: .steam)) == ["Dampf"])
    }

    @Test(arguments: [
        (Duration.seconds(180), "3:00"), (.seconds(5), "0:05"), (.milliseconds(4200), "0:05"),
        (.seconds(3750), "1:02:30"), (.zero, "0:00"),
    ])
    func formatsClock(duration: Duration, expected: String) {
        #expect(SettingFormatter.clock(duration) == expected)
    }
}
