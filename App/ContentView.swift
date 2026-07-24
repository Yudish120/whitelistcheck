import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            NavigationStack { DashboardView() }
                .tabItem { Label("Канал", systemImage: "antenna.radiowaves.left.and.right") }

            NavigationStack { ProfileView() }
                .tabItem { Label("Профиль", systemImage: "slider.horizontal.3") }

            NavigationStack { LogsView() }
                .tabItem { Label("Логи", systemImage: "terminal") }
        }
        .tint(.cyan)
    }
}

private struct DashboardView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                connectionHeader
                channelButton
                metrics
                route
                testButtons
                notice
            }
            .padding()
        }
        .background(AppBackground())
        .navigationTitle("WhiteList Test")
    }

    private var connectionHeader: some View {
        Card {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.18))
                        .frame(width: 58, height: 58)
                    Image(systemName: model.ready ? "checkmark.shield.fill" : "shield")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(statusColor)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(model.statusText)
                        .font(.title3.bold())

                    Text("\(model.network.interface) • \(model.profile.provider) / \(model.profile.transport)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Circle()
                    .fill(model.network.online ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
            }
        }
    }

    private var channelButton: some View {
        Button {
            Task { await model.toggleChannel() }
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: model.channelRunning
                                ? [.red.opacity(0.9), .orange]
                                : [.cyan, .green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 158, height: 158)
                    .shadow(color: statusColor.opacity(0.35), radius: 28)

                VStack(spacing: 9) {
                    Image(systemName: model.channelRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 36, weight: .bold))
                    Text(model.channelRunning ? "Остановить" : "Запустить канал")
                        .font(.headline)
                }
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
            }
        }
        .disabled((!model.canTest && !model.channelRunning) || model.busy)
        .opacity((model.canTest || model.channelRunning) ? 1 : 0.45)
        .padding(.vertical, 7)
    }

    private var metrics: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            Metric(title: "Check", value: model.checkMs.map { "\($0) мс" } ?? "—")
            Metric(title: "HTTP Ping", value: model.pingMs.map { "\($0) мс" } ?? "—")
            Metric(title: "SOCKS5", value: model.ready ? "готов" : "—")
            Metric(title: "Uptime", value: model.uptimeText)
        }
    }

    private var route: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Label("Какой канал запущен", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.headline)

                RouteRow(icon: "iphone", title: "iPhone", value: "olcRTC client")
                RouteRow(icon: "lock.fill", title: "Локальный SOCKS5", value: "127.0.0.1:\(model.profile.socksPort)")
                RouteRow(icon: "video.fill", title: "Provider", value: model.profile.provider)
                RouteRow(icon: "waveform.path", title: "Transport", value: model.profile.transport)
                RouteRow(icon: "server.rack", title: "VPS", value: model.ready ? "peer connected" : "waiting")
            }
        }
    }

    private var testButtons: some View {
        VStack(spacing: 11) {
            Button {
                Task { await model.check() }
            } label: {
                Label("Check: peer и SOCKS5", systemImage: "checkmark.circle")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(model.busy || !model.canTest)

            Button {
                Task { await model.ping() }
            } label: {
                Label("Ping: HTTP через VPS", systemImage: "network")
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(model.busy || !model.canTest)

            if model.busy {
                ProgressView("Проверка WebRTC…")
                    .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private var notice: some View {
        VStack(spacing: 10) {
            if !model.message.isEmpty {
                Text(model.message)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(model.isError ? Color.red : Color.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(13)
                    .background(
                        (model.isError ? Color.red : Color.green).opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 13)
                    )
            }

            Text("Это тест транспорта без системного VPN. Канал и SOCKS5 настоящие, но трафик остальных приложений iPhone в него пока не направляется. Для стабильного теста держи приложение открытым.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(13)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
        }
    }

    private var statusColor: Color {
        if model.ready { return .green }
        if model.channelRunning || model.busy { return .orange }
        return .cyan
    }
}

private struct ProfileView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showImport = false

    var body: some View {
        Form {
            Section("WebRTC") {
                Picker("Provider", selection: $model.profile.provider) {
                    Text("Jitsi").tag("jitsi")
                    Text("WB Stream").tag("wbstream")
                    Text("Telemost").tag("telemost")
                }

                Picker("Transport", selection: $model.profile.transport) {
                    Text("DataChannel").tag("datachannel")
                    Text("VP8 Channel").tag("vp8channel")
                }

                TextField("Room URL / ID", text: $model.profile.room)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("Client ID", text: $model.profile.clientID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("64-символьный общий ключ", text: $model.secret)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("Проверка") {
                Stepper("SOCKS5 порт: \(model.profile.socksPort)",
                        value: $model.profile.socksPort,
                        in: 1024...65535)

                TextField("Ping URL", text: $model.profile.pingURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("DNS", text: $model.profile.dnsServer)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("VP8 и логи") {
                Stepper("FPS: \(model.profile.vp8FPS)",
                        value: $model.profile.vp8FPS,
                        in: 1...60)

                Stepper("Batch: \(model.profile.vp8BatchSize)",
                        value: $model.profile.vp8BatchSize,
                        in: 1...64)

                Toggle("Максимальное логирование", isOn: $model.profile.debug)
            }

            Section {
                Button("Сохранить") {
                    model.save()
                }

                Button("Импорт YAML или olcrtc://") {
                    showImport = true
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle("Профиль")
        .sheet(isPresented: $showImport) {
            NavigationStack {
                VStack(spacing: 14) {
                    TextEditor(text: $model.importText)
                        .font(.system(.caption, design: .monospaced))
                        .padding(8)
                        .background(Color.black.opacity(0.25),
                                    in: RoundedRectangle(cornerRadius: 14))

                    Button("Импортировать") {
                        model.importConfiguration()
                        showImport = false
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding()
                .background(AppBackground())
                .navigationTitle("Импорт")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Закрыть") { showImport = false }
                    }
                }
            }
        }
    }
}

private struct LogsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 12) {
            ScrollView([.vertical, .horizontal]) {
                Text(model.logs)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            }
            .background(Color.black.opacity(0.35),
                        in: RoundedRectangle(cornerRadius: 16))

            HStack {
                Button("Обновить") {
                    model.refreshLogs()
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("Очистить") {
                    model.clearLogs()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding()
        .background(AppBackground())
        .navigationTitle("Логи")
    }
}

private struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(red: 0.07, green: 0.13, blue: 0.18).opacity(0.97),
                in: RoundedRectangle(cornerRadius: 18)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.08))
            )
    }
}

private struct Metric: View {
    let title: String
    let value: String

    var body: some View {
        Card {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
    }
}

private struct RouteRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 26)
                .foregroundStyle(.cyan)
            Text(title)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.025, green: 0.06, blue: 0.09),
                Color(red: 0.04, green: 0.10, blue: 0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(14)
            .foregroundStyle(.black)
            .background(
                LinearGradient(colors: [.cyan, .green],
                               startPoint: .leading,
                               endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(13)
            .background(Color.white.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.68 : 1)
    }
}
