import Foundation

struct TransportProfile: Codable {
    var provider = "jitsi"
    var transport = "datachannel"
    var room = "https://meet1.arbitr.ru/wlvpn-8fbccda03aa9cc46c60a"
    var clientID = UUID().uuidString.lowercased()
    var socksPort = 8808
    var pingURL = "https://www.google.com/generate_204"
    var dnsServer = "8.8.8.8:53"
    var vp8FPS = 30
    var vp8BatchSize = 8
    var livenessIntervalMs = 10_000
    var livenessTimeoutMs = 5_000
    var livenessFailures = 3
    var debug = true

    var isValid: Bool {
        !provider.isEmpty &&
        !transport.isEmpty &&
        !room.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !clientID.isEmpty &&
        (1024...65535).contains(socksPort)
    }
}

enum ImportParser {
    static func parse(_ text: String, base: TransportProfile) -> (TransportProfile, String?) {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("olcrtc://") {
            return parseURI(text, base: base)
        }
        return parseYAML(text, base: base)
    }

    private static func parseURI(_ raw: String, base: TransportProfile) -> (TransportProfile, String?) {
        var profile = base
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let scheme = text.range(of: "olcrtc://") else { return (profile, nil) }

        let body = String(text[scheme.upperBound...])
        guard let question = body.firstIndex(of: "?"),
              let at = body.firstIndex(of: "@"),
              let hash = body.firstIndex(of: "#"),
              question < at, at < hash else {
            return (profile, nil)
        }

        profile.provider = String(body[..<question])
        profile.transport = String(body[body.index(after: question)..<at])

        let room = String(body[body.index(after: at)..<hash])
        profile.room = room.removingPercentEncoding ?? room

        let tail = String(body[body.index(after: hash)...])
        let keyEnd = tail.firstIndex(where: { $0 == "%" || $0 == "$" }) ?? tail.endIndex
        let key = String(tail[..<keyEnd])

        if let percent = tail.firstIndex(of: "%") {
            let after = tail.index(after: percent)
            let clientEnd = tail[after...].firstIndex(of: "$") ?? tail.endIndex
            let client = String(tail[after..<clientEnd])
            if !client.isEmpty { profile.clientID = client }
        }

        return (profile, key)
    }

    private static func parseYAML(_ text: String, base: TransportProfile) -> (TransportProfile, String?) {
        var profile = base
        var key: String?

        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.hasPrefix("#"), let colon = line.firstIndex(of: ":") else { continue }

            let name = line[..<colon]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            let value = line[line.index(after: colon)...]
                .trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))

            switch name {
            case "provider", "carrier":
                if !value.isEmpty { profile.provider = value }
            case "transport":
                if !value.isEmpty { profile.transport = value }
            case "id", "room", "room_id", "roomurl", "room_url":
                if value.contains("meet") || value.contains("wlvpn") || value.contains("room") {
                    profile.room = value
                }
            case "client_id", "clientid", "device_id", "deviceid":
                if !value.isEmpty { profile.clientID = value }
            case "key", "key_hex", "keyhex":
                if value.count >= 32 { key = value }
            case "port", "socks_port":
                if let port = Int(value) { profile.socksPort = port }
            default:
                break
            }
        }

        return (profile, key)
    }
}
