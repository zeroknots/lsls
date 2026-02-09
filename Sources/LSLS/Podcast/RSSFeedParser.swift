import Foundation

struct RSSEpisode {
    let title: String
    let audioUrl: String
    let pubDate: Date
    let duration: TimeInterval
    let description: String?
    let fileSize: Int64?
}

struct RSSFeed {
    let title: String
    let author: String?
    let description: String?
    let artworkUrl: String?
    let episodes: [RSSEpisode]
}

final class RSSFeedParser: NSObject, XMLParserDelegate {
    private var feedTitle: String?
    private var feedAuthor: String?
    private var feedDescription: String?
    private var feedArtwork: String?
    private var episodes: [RSSEpisode] = []

    private var currentTitle: String?
    private var currentAudioUrl: String?
    private var currentPubDate: Date?
    private var currentDuration: TimeInterval = 0
    private var currentDescription: String?
    private var currentFileSize: Int64?

    private var currentElement = ""
    private var currentText = ""
    private var isInItem = false
    private var isInChannel = false

    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return fmt
    }()

    private static let altDateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return fmt
    }()

    static func parse(data: Data) throws -> RSSFeed {
        let parser = XMLParser(data: data)
        let delegate = RSSFeedParser()
        parser.delegate = delegate

        guard parser.parse() else {
            throw PodcastError.parseFailed
        }

        return RSSFeed(
            title: delegate.feedTitle ?? "Unknown Podcast",
            author: delegate.feedAuthor,
            description: delegate.feedDescription,
            artworkUrl: delegate.feedArtwork,
            episodes: delegate.episodes
        )
    }

    static func fetch(url: URL) async throws -> RSSFeed {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        let session = URLSession(configuration: config)
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw PodcastError.httpError(statusCode: code)
        }

        return try parse(data: data)
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        currentText = ""

        if elementName == "channel" {
            isInChannel = true
        } else if elementName == "item" {
            isInItem = true
            currentTitle = nil
            currentAudioUrl = nil
            currentPubDate = nil
            currentDuration = 0
            currentDescription = nil
            currentFileSize = nil
        } else if elementName == "enclosure", isInItem {
            let type = attributeDict["type"] ?? ""
            let isAudio = type.isEmpty || type.hasPrefix("audio") || type == "application/octet-stream"
            if isAudio, let url = attributeDict["url"], !url.isEmpty {
                currentAudioUrl = url
                if let lengthStr = attributeDict["length"], let length = Int64(lengthStr) {
                    currentFileSize = length
                }
            }
        } else if elementName == "itunes:image" && !isInItem {
            if let href = attributeDict["href"] {
                feedArtwork = href
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if isInItem {
            switch elementName {
            case "title":
                currentTitle = trimmed
            case "pubDate":
                currentPubDate = Self.dateFormatter.date(from: trimmed)
                    ?? Self.altDateFormatter.date(from: trimmed)
            case "itunes:duration":
                currentDuration = parseDuration(trimmed)
            case "description", "itunes:summary":
                if currentDescription == nil && !trimmed.isEmpty {
                    currentDescription = trimmed
                }
            case "item":
                if let title = currentTitle,
                   let audioUrl = currentAudioUrl {
                    episodes.append(RSSEpisode(
                        title: title,
                        audioUrl: audioUrl,
                        pubDate: currentPubDate ?? Date(),
                        duration: currentDuration,
                        description: currentDescription,
                        fileSize: currentFileSize
                    ))
                }
                isInItem = false
            default:
                break
            }
        } else if isInChannel {
            switch elementName {
            case "title":
                if feedTitle == nil { feedTitle = trimmed }
            case "itunes:author":
                if feedAuthor == nil { feedAuthor = trimmed }
            case "description":
                if feedDescription == nil && !trimmed.isEmpty { feedDescription = trimmed }
            case "channel":
                isInChannel = false
            default:
                break
            }
        }

        currentText = ""
    }

    private func parseDuration(_ str: String) -> TimeInterval {
        // Handle seconds-only format
        if let seconds = TimeInterval(str) {
            return seconds
        }
        // Handle HH:MM:SS or MM:SS format
        let components = str.split(separator: ":").compactMap { Int($0) }
        switch components.count {
        case 3: return TimeInterval(components[0] * 3600 + components[1] * 60 + components[2])
        case 2: return TimeInterval(components[0] * 60 + components[1])
        case 1: return TimeInterval(components[0])
        default: return 0
        }
    }
}
