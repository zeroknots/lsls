import Foundation

enum PodcastError: LocalizedError {
    case invalidQuery
    case invalidURL
    case httpError(statusCode: Int)
    case parseFailed
    case downloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidQuery: return "Invalid search query"
        case .invalidURL: return "Invalid URL"
        case .httpError(let code): return "HTTP error: \(code)"
        case .parseFailed: return "Failed to parse RSS feed"
        case .downloadFailed(let msg): return "Download failed: \(msg)"
        }
    }
}
