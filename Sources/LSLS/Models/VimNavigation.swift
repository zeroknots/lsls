import Foundation
import SwiftUI

@MainActor
@Observable
final class VimNavigation {
    enum FocusZone: Equatable {
        case sidebar
        case content
        case contentDetail
    }

    var isActive = false
    var focusZone: FocusZone = .sidebar

    var sidebarIndex: Int = 0
    var contentIndex: Int = 0
    var detailIndex: Int = 0

    var sidebarItemCount: Int = 0
    var contentItemCount: Int = 0
    var detailItemCount: Int = 0

    var sidebarSections: [SidebarSection] = []
    var enterTrigger: Int = 0
    var hasActiveSelection: Bool = false

    var isGridMode: Bool = false
    var gridColumns: Int = 1

    func activate() {
        isActive = true
        focusZone = .sidebar
    }

    func deactivate() {
        isActive = false
    }

    func moveDown() {
        switch focusZone {
        case .sidebar:
            if sidebarIndex < sidebarItemCount - 1 {
                sidebarIndex += 1
            }
        case .content:
            if isGridMode {
                let newIndex = contentIndex + gridColumns
                if newIndex < contentItemCount {
                    contentIndex = newIndex
                }
            } else {
                if contentIndex < contentItemCount - 1 {
                    contentIndex += 1
                }
            }
        case .contentDetail:
            if detailIndex < detailItemCount - 1 {
                detailIndex += 1
            }
        }
    }

    func moveUp() {
        switch focusZone {
        case .sidebar:
            if sidebarIndex > 0 {
                sidebarIndex -= 1
            }
        case .content:
            if isGridMode {
                let newIndex = contentIndex - gridColumns
                if newIndex >= 0 {
                    contentIndex = newIndex
                }
            } else {
                if contentIndex > 0 {
                    contentIndex -= 1
                }
            }
        case .contentDetail:
            if detailIndex > 0 {
                detailIndex -= 1
            }
        }
    }

    func moveRight() {
        switch focusZone {
        case .sidebar:
            focusZone = .content
            contentIndex = 0
        case .content:
            enterTrigger += 1
        case .contentDetail:
            enterTrigger += 1
        }
    }

    func moveLeft() {
        switch focusZone {
        case .sidebar:
            break
        case .content:
            focusZone = .sidebar
        case .contentDetail:
            focusZone = .content
        }
    }

    func triggerEnter() {
        enterTrigger += 1
    }

    func resetContentState() {
        contentIndex = 0
        detailIndex = 0
        contentItemCount = 0
        detailItemCount = 0
        hasActiveSelection = false
        isGridMode = false
        gridColumns = 1
    }
}
