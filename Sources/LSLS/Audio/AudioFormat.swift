import Foundation

struct AudioFormat: Sendable, Equatable {
    var codec: String
    var sampleRate: Int
    var bitDepth: Int?
    var bitRate: Int?
    var channels: Int

    var displayString: String {
        var parts: [String] = [codec]

        if let depth = bitDepth, depth > 0 {
            let rateKHz = Double(sampleRate) / 1000.0
            let rateStr = rateKHz.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(rateKHz))" : String(format: "%.1f", rateKHz)
            parts.append("\(depth)/\(rateStr)")
        } else if let br = bitRate, br > 0 {
            let kbps = br / 1000
            parts.append("\(kbps)kbps")
        }

        return parts.joined(separator: " ")
    }
}
