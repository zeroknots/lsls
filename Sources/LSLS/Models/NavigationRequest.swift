import Foundation
import SwiftUI

@MainActor
@Observable
final class NavigationRequest {
    var scrollToTrackId: Int64?
    var selectArtistId: Int64?
    var isCommandPaletteVisible: Bool = false
    var isPlaylistPaletteVisible: Bool = false

    func requestNavigation(toArtistId: Int64, trackId: Int64?) {
        self.selectArtistId = toArtistId
        self.scrollToTrackId = trackId
    }

    func clearNavigation() {
        selectArtistId = nil
        scrollToTrackId = nil
    }
}
