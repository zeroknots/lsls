import Foundation
import Testing

@testable import FLACMusic

@Suite("TimeFormatter")
struct TimeFormatterTests {

    // MARK: - format (short)

    @Test("format zero")
    func formatZero() {
        #expect(TimeFormatter.format(0) == "0:00")
    }

    @Test("format seconds only")
    func formatSecondsOnly() {
        #expect(TimeFormatter.format(5) == "0:05")
        #expect(TimeFormatter.format(59) == "0:59")
    }

    @Test("format minutes and seconds")
    func formatMinutesSeconds() {
        #expect(TimeFormatter.format(60) == "1:00")
        #expect(TimeFormatter.format(90) == "1:30")
        #expect(TimeFormatter.format(226) == "3:46")
    }

    @Test("format large values")
    func formatLarge() {
        #expect(TimeFormatter.format(3600) == "60:00")
        #expect(TimeFormatter.format(3661) == "61:01")
    }

    @Test("format handles NaN and infinity")
    func formatInvalidValues() {
        #expect(TimeFormatter.format(.nan) == "0:00")
        #expect(TimeFormatter.format(.infinity) == "0:00")
        #expect(TimeFormatter.format(-.infinity) == "0:00")
    }

    @Test("format handles negative")
    func formatNegative() {
        #expect(TimeFormatter.format(-5) == "0:00")
    }

    // MARK: - formatLong

    @Test("formatLong without hours")
    func formatLongNoHours() {
        #expect(TimeFormatter.formatLong(0) == "0:00")
        #expect(TimeFormatter.formatLong(90) == "1:30")
        #expect(TimeFormatter.formatLong(3599) == "59:59")
    }

    @Test("formatLong with hours")
    func formatLongWithHours() {
        #expect(TimeFormatter.formatLong(3600) == "1:00:00")
        #expect(TimeFormatter.formatLong(3661) == "1:01:01")
        #expect(TimeFormatter.formatLong(7200) == "2:00:00")
    }

    @Test("formatLong handles invalid values")
    func formatLongInvalid() {
        #expect(TimeFormatter.formatLong(.nan) == "0:00")
        #expect(TimeFormatter.formatLong(.infinity) == "0:00")
        #expect(TimeFormatter.formatLong(-1) == "0:00")
    }
}
