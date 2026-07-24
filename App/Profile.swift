import Foundation

struct TransportProfile: Codable {
    var provider = "jitsi"
    var transport = "datachannel"
    var room = "https://meet1.arbitr.ru/wlvpn-8fbccda03aa9cc46c60a"
    var clientID = UUID().uuidString.lowercased()
    var socksPort = 8808
    var pingURL = "https://www.google.com/generate_204"
    var dnsServer = "1.1.1.1:53"
    var vp8FPS = 30
    var vp8BatchSize = 8
    var livenessIntervalMs = 10_000
    var livenessTimeoutMs = 5_000
    var livenessFailures = 3
    var debug = true

    var isValid: Bool {
        !provider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !transport.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !room.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (1024...65535).contains(socksPort)
    }

    var compactDescription: String {
        "\(provider) / \(transport)"
    }
}

enum ImportParser {
    static func parse(_ text: String, base: TransportProfile) -> (TransportProfile, String?) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if clean.hasPrefix("olcrtc://") {
            return parseURI(clean, base: base)
        }

        return parseYAML(clean, base: base)
    }

    private static func parseURI(
        _ raw: String,
        base: TransportProfile
    ) -> (TransportProfile, String?) {
        var profile = base

        guard let scheme = raw.range(of: "olcrtc://") else {
            return (profile, nil)
        }

        let body = String(raw[scheme.upperBound...])

        guard
            let question = body.firstIndex(of: "?"),
            let at = body.firstIndex(of: "@"),
            let hash = body.firstIndex(of: "#"),
            question < at,
            at < hash
        else {
            return (profile, nil)
        }

        profile.provider = String(body[..<question])

        let transportBlock = String(body[body.index(after: question)..<at])
        if let payloadStart = transportBlock.firstIndex(of: "<") {
            profile.transport = String(transportBlock[..<payloadStart])
        } else {
            profile.transport = transportBlock
        }

        let room = String(body[body.index(after: at)..<hash])
        profile.room = room.removingPercentEncoding ?? room

        let tail = String(body[body.index(after: hash)...])
        let keyEnd = tail.firstIndex(where: { $0 == "$" || $0 == "%" }) ?? tail.endIndex
        let key = String(tail[..<keyEnd])

        if let percent = tail.firstIndex(of: "%") {
            let after = tail.index(after: percent)
            let clientEnd = tail[after...].firstIndex(of: "$") ?? tail.endIndex
            let client = String(tail[after..<clientEnd])
            if !client.isEmpty {
                profile.clientID = client
            }
        }

        return (profile, key)
    }

    private static func parseYAML(
        _ text: String,
        base: TransportProfile
    ) -> (TransportProfile, String?) {
        var profile = base
        var key: String?

        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)

            guard
                !line.isEmpty,
                !line.hasPrefix("#"),
                let colon = line.firstIndex(of: ":")
            else {
                continue
            }

            let name = line[..<colon]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            let value = line[line.index(after: colon)...]
                .trimmingCharacters(in: CharacterSet(charactersIn: " \"'\t"))

            switch name {
            case "provider", "carrier":
                if !value.isEmpty {
                    profile.provider = value
                }

            case "transport":
                if !value.isEmpty {
                    profile.transport = value
                }

            case "id", "room", "room_id", "roomurl", "room_url":
                if !value.isEmpty {
                    profile.room = value
                }

            case "client_id", "clientid", "device_id", "deviceid":
                if !value.isEmpty {
                    profile.clientID = value
                }

            case "key", "key_hex", "keyhex":
                if !value.isEmpty {
                    key = value
                }

            case "port", "socks_port":
                if let port = Int(value) {
                    profile.socksPort = port
                }

            case "dns", "dns_server":
                if !value.isEmpty {
                    profile.dnsServer = value
                }

            case "fps":
                if let fps = Int(value) {
                    profile.vp8FPS = fps
                }

            case "batch_size", "batch":
                if let batch = Int(value) {
                    profile.vp8BatchSize = batch
                }

            case "debug":
                profile.debug = ["true", "yes", "1"].contains(value.lowercased())

            default:
                break
            }
        }

        profile.provider = profile.provider.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.transport = profile.transport.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.room = profile.room.trimmingCharacters(in: .whitespacesAndNewlines)

        return (profile, key?.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
