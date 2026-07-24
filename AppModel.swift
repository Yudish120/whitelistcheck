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
    @Published var logs = "Запусти Check, Ping или тестовый канал."
    @Published var channelStartedAt: Date?

    let network = NetworkMonitor()

    private let defaults = UserDefaults.standard
    private let profileKey = "wlvpn.transport.profile.v021"
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

    var canTest: Bool {
        network.online && profile.isValid && secret.count >= 32 && !busy
    }

    var uptimeText: String {
        guard let channelStartedAt else { return "—" }
        let seconds = Int(Date().timeIntervalSince(channelStartedAt))
        let minutes = seconds / 60
        return minutes > 0 ? "\(minutes) мин" : "\(seconds) сек"
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(profile)
            defaults.set(data, forKey: profileKey)

            if !secret.isEmpty {
                try KeychainStore.save(secret)
            }

            setMessage("Профиль сохранён. Ключ находится в Keychain.", error: false)
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
        setMessage("Конфигурация импортирована.", error: false)
    }

    func check() async {
        guard canTest else {
            setMessage("Заполни профиль, ключ и проверь интернет.", error: true)
            return
        }

        busy = true
        statusText = "Check…"
        WLOLCClearLogs()
        configure()
        defer { busy = false; refreshLogs() }

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
                    15_000,
                    vp8FPS,
                    vp8BatchSize,
                    &error
                )

                if let error { throw error }
                return elapsed
            }.value

            checkMs = result
            statusText = "Peer найден"
            setMessage("Check успешен за \(result) мс.", error: false)
        } catch {
            statusText = "Check failed"
            setMessage(error.localizedDescription, error: true)
        }
    }

    func ping() async {
        guard canTest else {
            setMessage("Заполни профиль, ключ и проверь интернет.", error: true)
            return
        }

        busy = true
        statusText = "HTTP Ping…"
        WLOLCClearLogs()
        configure()
        defer { busy = false; refreshLogs() }

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
                    25_000,
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
            setMessage("HTTP прошёл через VPS за \(result) мс.", error: false)
        } catch {
            statusText = "Ping failed"
            setMessage(error.localizedDescription, error: true)
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

        guard canTest else {
            setMessage("Заполни профиль, ключ и проверь интернет.", error: true)
            return
        }

        busy = true
        statusText = "Вход в комнату…"
        WLOLCClearLogs()
        configure()
        defer { busy = false; refreshLogs() }

        do {
            var startError: NSError?
            let started = WLOLCStart(
                profile.provider,
                profile.transport,
                profile.room,
                profile.clientID,
                secret,
                profile.socksPort,
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
                let result = WLOLCWaitReady(20_000, &readyError)
                if let readyError { throw readyError }
                return result
            }.value

            ready = isReady
            statusText = isReady ? "Канал готов" : "Не готов"
            setMessage(
                isReady
                    ? "WebRTC peer найден, SOCKS5 127.0.0.1:\(profile.socksPort) готов."
                    : "Канал запущен, но SOCKS5 не готов.",
                error: !isReady
            )
        } catch {
            WLOLCStop()
            channelRunning = false
            ready = false
            channelStartedAt = nil
            statusText = "Ошибка"
            setMessage(error.localizedDescription, error: true)
        }
    }

    func clearLogs() {
        WLOLCClearLogs()
        logs = ""
    }

    func refreshLogs() {
        let value = WLOLCLogs()
        if !value.isEmpty { logs = value }
        channelRunning = WLOLCIsRunning()
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

    private func setMessage(_ text: String, error: Bool) {
        message = text
        isError = error
    }
}
