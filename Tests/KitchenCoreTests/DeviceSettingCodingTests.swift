import Foundation
import Testing

@testable import KitchenCore

@Suite("DeviceSetting JSON")
struct DeviceSettingCodingTests {
    private func decode(_ json: String) throws -> DeviceSetting {
        try JSONDecoder().decode(DeviceSetting.self, from: Data(json.utf8))
    }

    @Test func decodesManualSettingWithReverseRotation() throws {
        let setting = try decode(#"{"heat": 100, "speed": 1, "reverse": true, "seconds": 1200}"#)
        #expect(setting == DeviceSetting(heat: .celsius(100), rotation: .reverse(speed: 1), duration: .seconds(1200)))
    }

    @Test func decodesSteam() throws {
        let setting = try decode(#"{"program": "steam", "heat": "steam", "seconds": 720}"#)
        #expect(setting == DeviceSetting(program: .steam, heat: .steam, duration: .seconds(720)))
    }

    @Test func emptyObjectIsManualWithoutValues() throws {
        #expect(try decode("{}") == DeviceSetting())
    }

    @Test func rejectsUnknownHeatString() {
        #expect(throws: DecodingError.self) { try decode(#"{"heat": "hot"}"#) }
    }

    @Test(arguments: [
        DeviceSetting(heat: .celsius(120), rotation: .reverse(speed: 1), duration: .seconds(180)),
        DeviceSetting(program: .steam, heat: .steam, duration: .seconds(300)),
        DeviceSetting(rotation: .forward(speed: 5), duration: .seconds(5)),
        DeviceSetting(),
    ])
    func roundTrips(setting: DeviceSetting) throws {
        let data = try JSONEncoder().encode(setting)
        #expect(try JSONDecoder().decode(DeviceSetting.self, from: data) == setting)
    }
}
