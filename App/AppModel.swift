import Foundation
import UIKit

@MainActor
final class AppModel: ObservableObject {
    @Published var profile: TransportProfile
    @Published var secret: String
    @Published var importText = ""
    @Published var statusText = "Не подключён"
    @Published var message = ""
    @Published var isError = false
    @Published var busy = false
    @Published var channelRunning = false
    @Published var ready = false
    @Published var checkMs: Int64?
    @Published var pingMs: Int64?
    @Published var logs = "Логи появятся после запуска проверки."
    @Published var channelStartedAt: Date?
    @Published var roomReachable: Bool?

    let network = NetworkMonitor()

    private let defaults = UserDefaults.standard
    private let profileKey = "wlvpn.transport.profile.v030"
    private var logTask: Task<Void, Never>?

    init() {
        if let data = defaults.data(forKey: profileKey),
           let saved = try? JSONDecoder().decode(TransportProfile.self, from: data) {
            profile = saved
        } else {
            profile = TransportProfile()
        }

        secret = KeychainStore.load()
        channelRunning = WLOLCIsRunning()
        startLogRefresh()
    }

    deinit {
        logTask?.cancel()
    }

    var configurationIssue: String? {
        if !network.online {
            return "На iPhone нет доступного интернета."
        }

        if profile.provider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Не выбран provider."
        }

        if profile.transport.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Не выбран transport."
        }

        if profile.room.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Не указан Room URL."
        }

        if !profile.isValid {
            return "В профиле есть некорректные параметры."
        }

        let normalizedKey = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        let hex = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        if normalizedKey.count != 64 ||
            normalizedKey.unicodeScalars.contains(where: { !hex.contains($0) }) {
            return "Общий ключ должен содержать ровно 64 hex-символа."
        }

        return nil
    }

    var canTest: Bool {
        configurationIssue == nil && !busy
    }

    var uptimeText: String {
        guard let channelStartedAt else { return "—" }

        let seconds = max(0, Int(Date().timeIntervalSince(channelStartedAt)))
        if seconds >= 3600 {
            return "\(seconds / 3600) ч \(seconds % 3600 / 60) мин"
        }
        if seconds >= 60 {
            return "\(seconds / 60) мин"
        }
        return "\(seconds) сек"
    }

    var peerStateText: String {
        if ready { return "подключён" }
        if channelRunning { return "ожидание" }
        return "не найден"
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(profile)
            defaults.set(data, forKey: profileKey)

            let cleanSecret = secret.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanSecret.isEmpty {
                secret = cleanSecret
                try KeychainStore.save(cleanSecret)
            }

            setMessage("Профиль сохранён. Ключ помещён в Keychain.", error: false)
        } catch {
            setMessage(error.localizedDescription, error: true)
        }
    }

    func importConfiguration() {
        let parsed = ImportParser.parse(importText, base: profile)
        profile = parsed.0

        if let key = parsed.1, !key.isEmpty {
            secret = key
        }

        save()

        let issue = configurationIssue
        if let issue {
            setMessage("Импорт выполнен, но профиль пока не готов: \(issue)", error: true)
        } else {
            setMessage(
                "Импортировано: \(profile.provider) / \(profile.transport), SOCKS5 :\(profile.socksPort).",
                error: false
            )
        }
    }

    func pasteImportText() {
        importText = UIPasteboard.general.string ?? ""
    }

    func checkRoomHost() async {
        guard let url = URL(string: profile.room) else {
            roomReachable = false
            setMessage("Room URL имеет неправильный формат.", error: true)
            return
        }

        busy = true
        statusText = "Проверка Jitsi…"
        defer { busy = false }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw NSError(
                    domain: "WhiteListTransport",
                    code: 20,
                    userInfo: [NSLocalizedDescriptionKey: "Нет HTTP-ответа от Jitsi."]
                )
            }

            roomReachable = (200...499).contains(http.statusCode)
            statusText = roomReachable == true ? "Jitsi доступен" : "Jitsi недоступен"

            setMessage(
                roomReachable == true
                    ? "Адрес комнаты открывается с этой сети. Теперь нужен серверный peer на VPS."
                    : "Jitsi вернул HTTP \(http.statusCode). Попробуй другой Jitsi-хост.",
                error: roomReachable != true
            )
        } catch {
            roomReachable = false
            statusText = "Jitsi недоступен"
            setMessage(
                "iPhone не открыл \(profile.room). Проверь адрес в Safari или попробуй другой Jitsi-сервер.",
                error: true
            )
        }
    }

    func check() async {
        guard validateBeforeAction() else { return }

        busy = true
        statusText = "Поиск peer…"
        WLOLCClearLogs()
        configure()
        defer {
            busy = false
            refreshLogs()
        }

        let provider = profile.provider
        let transport = profile.transport
        let room = profile.room
        let clientID = profile.clientID
        let key = secret
        let socksPort = profile.socksPort
        let vp8FPS = profile.vp8FPS
        let vp8BatchSize = profile.vp8BatchSize

        do {
            let result = try await Task.detached(priority: .userInitiated) {
                var error: NSError?
                let elapsed = WLOLCCheck(
                    provider,
                    transport,
                    room,
                    clientID,
                    key,
                    socksPort,
                    45_000,
                    vp8FPS,
                    vp8BatchSize,
                    &error
                )

                if let error { throw error }
                return elapsed
            }.value

            checkMs = result
            statusText = "Peer найден"
            setMessage("Check успешен за \(result) мс. SOCKS5 готов.", error: false)
        } catch {
            statusText = "Peer не найден"
            setMessage(friendlyMessage(for: error), error: true)
        }
    }

    func ping() async {
        guard validateBeforeAction() else { return }

        busy = true
        statusText = "HTTP через VPS…"
        WLOLCClearLogs()
        configure()
        defer {
            busy = false
            refreshLogs()
        }

        let provider = profile.provider
        let transport = profile.transport
        let room = profile.room
        let clientID = profile.clientID
        let key = secret
        let socksPort = profile.socksPort
        let pingURL = profile.pingURL
        let vp8FPS = profile.vp8FPS
        let vp8BatchSize = profile.vp8BatchSize

        do {
            let result = try await Task.detached(priority: .userInitiated) {
                var error: NSError?
                let elapsed = WLOLCPing(
                    provider,
                    transport,
                    room,
                    clientID,
                    key,
                    socksPort,
                    60_000,
                    pingURL,
                    vp8FPS,
                    vp8BatchSize,
                    &error
                )

                if let error { throw error }
                return elapsed
            }.value

            pingMs = result
            statusText = "Трафик проходит"
            setMessage("HTTP-запрос прошёл через VPS за \(result) мс.", error: false)
        } catch {
            statusText = "Ping не прошёл"
            setMessage(friendlyMessage(for: error), error: true)
        }
    }

    func toggleChannel() async {
        if WLOLCIsRunning() {
            WLOLCStop()
            channelRunning = false
            ready = false
            channelStartedAt = nil
            statusText = "Остановлен"
            setMessage("Тестовый канал остановлен.", error: false)
            refreshLogs()
            return
        }

        guard validateBeforeAction() else { return }

        busy = true
        statusText = "Вход в комнату…"
        WLOLCClearLogs()
        configure()
        defer {
            busy = false
            refreshLogs()
        }

        let provider = profile.provider
        let transport = profile.transport
        let room = profile.room
        let clientID = profile.clientID
        let key = secret
        let socksPort = profile.socksPort

        do {
            var startError: NSError?
            let started = WLOLCStart(
                provider,
                transport,
                room,
                clientID,
                key,
                socksPort,
                "",
                "",
                &startError
            )

            if !started {
                throw startError ?? NSError(
                    domain: "WhiteListTransport",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "olcRTC не запустился."]
                )
            }

            channelRunning = true
            channelStartedAt = Date()
            statusText = "Ожидание peer…"

            let isReady = try await Task.detached(priority: .userInitiated) {
                var readyError: NSError?
                let result = WLOLCWaitReady(60_000, &readyError)
                if let readyError { throw readyError }
                return result
            }.value

            ready = isReady
            statusText = isReady ? "Канал готов" : "Peer не найден"

            setMessage(
                isReady
                    ? "WebRTC peer найден. SOCKS5 127.0.0.1:\(socksPort) готов."
                    : "Канал стартовал, но серверный peer не ответил.",
                error: !isReady
            )
        } catch {
            WLOLCStop()
            channelRunning = false
            ready = false
            channelStartedAt = nil
            statusText = "Peer не найден"
            setMessage(friendlyMessage(for: error), error: true)
        }
    }

    func clearLogs() {
        WLOLCClearLogs()
        logs = ""
    }

    func refreshLogs() {
        let value = WLOLCLogs()
        if !value.isEmpty {
            logs = value
        }

        channelRunning = WLOLCIsRunning()
    }

    private func validateBeforeAction() -> Bool {
        if let issue = configurationIssue {
            setMessage(issue, error: true)
            return false
        }

        return true
    }

    private func configure() {
        WLOLCConfigure(
            profile.debug,
            profile.livenessIntervalMs,
            profile.livenessTimeoutMs,
            profile.livenessFailures,
            profile.vp8FPS,
            profile.vp8BatchSize,
            profile.dnsServer
        )
    }

    private func startLogRefresh() {
        logTask?.cancel()

        logTask = Task {
            while !Task.isCancelled {
                refreshLogs()
                let delay: Duration = channelRunning ? .seconds(2) : .seconds(8)
                try? await Task.sleep(for: delay)
            }
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        let raw = error.localizedDescription
        let lowered = raw.lowercased()

        if lowered.contains("wait for peer") ||
            lowered.contains("start timed out") ||
            lowered.contains("deadline exceeded") {
            return """
            Клиент запустился, но серверный peer не найден. На VPS проверь службу \
            whitelistvpn-olcrtc и полное совпадение provider, transport, room и key.
            """
        }

        if lowered.contains("room") || lowered.contains("jitsi") {
            return "Не удалось войти в Jitsi-комнату. Проверь Room URL в Safari и попробуй другой Jitsi-хост."
        }

        if lowered.contains("key") || lowered.contains("crypto") || lowered.contains("handshake") {
            return "Peer найден, но шифрованный handshake не прошёл. Ключ клиента и сервера должен совпадать."
        }

        if lowered.contains("network") || lowered.contains("connection") {
            return "Сетевая ошибка: \(raw)"
        }

        return raw
    }

    private func setMessage(_ text: String, error: Bool) {
        message = text
        isError = error
    }
}
