import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label("Канал", systemImage: "antenna.radiowaves.left.and.right")
            }

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Профиль", systemImage: "slider.horizontal.3")
            }

            NavigationStack {
                LogsView()
            }
            .tabItem {
                Label("Логи", systemImage: "terminal")
            }
        }
        .tint(.cyan)
    }
}

private struct DashboardView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showRoute = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                statusCard
                channelButton
                metrics
                actionButtons
                messageCard
                routeCard
                explanation
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(AppBackground())
        .navigationTitle("WhiteList Test")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statusCard: some View {
        CompactCard {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.16))
                        .frame(width: 46, height: 46)

                    Image(systemName: model.ready ? "checkmark.shield.fill" : "shield")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(statusColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(model.statusText)
                        .font(.system(size: 19, weight: .bold))
                        .lineLimit(2)

                    Text("\(model.network.interface) • \(model.profile.compactDescription)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(spacing: 5) {
                    Circle()
                        .fill(model.network.online ? Color.green : Color.red)
                        .frame(width: 9, height: 9)

                    Text(model.network.online ? "online" : "offline")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var channelButton: some View {
        Button {
            Task {
                await model.toggleChannel()
            }
        } label: {
            HStack(spacing: 11) {
                if model.busy {
                    ProgressView()
                        .tint(.black)
                } else {
                    Image(systemName: model.channelRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 18, weight: .bold))
                }

                Text(model.channelRunning ? "Остановить канал" : "Запустить канал")
                    .font(.system(size: 17, weight: .bold))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                LinearGradient(
                    colors: model.channelRunning
                        ? [.red, .orange]
                        : [.cyan, .green],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 17)
            )
        }
        .disabled(model.busy)
        .opacity(model.busy ? 0.75 : 1)
    }

    private var metrics: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            MetricCell(title: "Check", value: model.checkMs.map { "\($0) мс" } ?? "—")
            MetricCell(title: "HTTP Ping", value: model.pingMs.map { "\($0) мс" } ?? "—")
            MetricCell(title: "SOCKS5", value: model.ready ? "готов" : "—")
            MetricCell(title: "Uptime", value: model.uptimeText)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 9) {
            CompactActionButton(
                title: "Check: peer и SOCKS5",
                icon: "checkmark.circle",
                primary: true,
                busy: model.busy
            ) {
                Task {
                    await model.check()
                }
            }

            CompactActionButton(
                title: "Ping: HTTP через VPS",
                icon: "network",
                primary: false,
                busy: model.busy
            ) {
                Task {
                    await model.ping()
                }
            }
        }
    }

    @ViewBuilder
    private var messageCard: some View {
        if !model.message.isEmpty {
            Text(model.message)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(model.isError ? Color.red : Color.green)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    (model.isError ? Color.red : Color.green).opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 14)
                )
        } else if let issue = model.configurationIssue {
            Text(issue)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    Color.orange.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 14)
                )
        }
    }

    private var routeCard: some View {
        CompactCard {
            DisclosureGroup(isExpanded: $showRoute) {
                VStack(spacing: 9) {
                    Divider().opacity(0.35)
                    RouteRow(icon: "iphone", title: "iPhone", value: "olcRTC client")
                    RouteRow(
                        icon: "lock.fill",
                        title: "SOCKS5",
                        value: "127.0.0.1:\(model.profile.socksPort)"
                    )
                    RouteRow(icon: "video.fill", title: "Provider", value: model.profile.provider)
                    RouteRow(icon: "waveform.path", title: "Transport", value: model.profile.transport)
                    RouteRow(icon: "server.rack", title: "VPS", value: model.peerStateText)
                }
                .padding(.top, 8)
            } label: {
                Label("Маршрут и состояние VPS", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 15, weight: .semibold))
            }
            .tint(.white)
        }
    }

    private var explanation: some View {
        Text(
            "Это тест olcRTC без системного VPN. Если появляется «peer не найден», " +
            "кнопка сработала, но сервер на VPS не вошёл в ту же комнату."
        )
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private var statusColor: Color {
        if model.ready {
            return .green
        }

        if model.channelRunning || model.busy {
            return .orange
        }

        return .cyan
    }
}

private struct ProfileView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showImport = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                providerCard
                connectionCard
                diagnosticsCard
                saveButtons
                validationCard
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(AppBackground())
        .navigationTitle("Профиль")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showImport) {
            ImportSheet(showImport: $showImport)
                .environmentObject(model)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var providerCard: some View {
        CompactCard {
            VStack(alignment: .leading, spacing: 11) {
                SectionTitle("WebRTC")

                Picker("Provider", selection: $model.profile.provider) {
                    Text("Jitsi").tag("jitsi")
                    Text("WB").tag("wbstream")
                    Text("Telemost").tag("telemost")
                }
                .pickerStyle(.segmented)

                Picker("Transport", selection: $model.profile.transport) {
                    Text("Data").tag("datachannel")
                    Text("VP8").tag("vp8channel")
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var connectionCard: some View {
        CompactCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle("Подключение")

                CompactTextField(
                    title: "Room URL",
                    placeholder: "https://meet1.arbitr.ru/room",
                    text: $model.profile.room,
                    secure: false
                )

                CompactTextField(
                    title: "Client ID",
                    placeholder: "UUID клиента",
                    text: $model.profile.clientID,
                    secure: false
                )

                CompactTextField(
                    title: "Общий ключ",
                    placeholder: "64 hex-символа",
                    text: $model.secret,
                    secure: true
                )

                HStack {
                    Text("SOCKS5")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Stepper(
                        "\(model.profile.socksPort)",
                        value: $model.profile.socksPort,
                        in: 1024...65535
                    )
                    .font(.system(size: 13, weight: .semibold))
                }
            }
        }
    }

    private var diagnosticsCard: some View {
        CompactCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle("Диагностика")

                CompactTextField(
                    title: "DNS",
                    placeholder: "1.1.1.1:53",
                    text: $model.profile.dnsServer,
                    secure: false
                )

                CompactTextField(
                    title: "Ping URL",
                    placeholder: "https://...",
                    text: $model.profile.pingURL,
                    secure: false
                )

                Toggle("Подробные логи", isOn: $model.profile.debug)
                    .font(.system(size: 14))

                Button {
                    Task {
                        await model.checkRoomHost()
                    }
                } label: {
                    Label(
                        model.roomReachable == true
                            ? "Jitsi доступен"
                            : "Проверить адрес Jitsi",
                        systemImage: model.roomReachable == true
                            ? "checkmark.circle.fill"
                            : "safari"
                    )
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(
                        Color.white.opacity(0.07),
                        in: RoundedRectangle(cornerRadius: 13)
                    )
                }
                .buttonStyle(.plain)
                .disabled(model.busy)
            }
        }
    }

    private var saveButtons: some View {
        VStack(spacing: 9) {
            Button {
                model.save()
            } label: {
                Label("Сохранить профиль", systemImage: "square.and.arrow.down")
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundStyle(.black)
                    .background(
                        LinearGradient(
                            colors: [.cyan, .green],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 15)
                    )
            }

            Button {
                showImport = true
            } label: {
                Label("Импорт YAML или olcrtc://", systemImage: "doc.on.clipboard")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        Color.white.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 15)
                    )
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var validationCard: some View {
        if let issue = model.configurationIssue {
            Text(issue)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    Color.orange.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 13)
                )
        }
    }
}

private struct ImportSheet: View {
    @EnvironmentObject private var model: AppModel
    @Binding var showImport: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                TextEditor(text: $model.importText)
                    .font(.system(size: 12, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(8)
                    .background(
                        Color.black.opacity(0.28),
                        in: RoundedRectangle(cornerRadius: 14)
                    )

                HStack(spacing: 9) {
                    Button {
                        model.pasteImportText()
                    } label: {
                        Label("Вставить", systemImage: "doc.on.clipboard")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                Color.white.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                    }

                    Button {
                        model.importConfiguration()
                        showImport = false
                    } label: {
                        Label("Импортировать", systemImage: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                LinearGradient(
                                    colors: [.cyan, .green],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(AppBackground())
            .navigationTitle("Импорт конфигурации")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") {
                        showImport = false
                    }
                }
            }
        }
    }
}

private struct LogsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    model.refreshLogs()
                } label: {
                    Label("Обновить", systemImage: "arrow.clockwise")
                }

                Button {
                    model.clearLogs()
                } label: {
                    Label("Очистить", systemImage: "trash")
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .buttonStyle(.bordered)

            ScrollView([.vertical, .horizontal]) {
                Text(model.logs)
                    .font(.system(size: 10.5, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .background(
                Color.black.opacity(0.35),
                in: RoundedRectangle(cornerRadius: 14)
            )
        }
        .padding(14)
        .background(AppBackground())
        .navigationTitle("Логи")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CompactCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(red: 0.065, green: 0.12, blue: 0.17).opacity(0.97),
                in: RoundedRectangle(cornerRadius: 17)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 17)
                    .stroke(Color.white.opacity(0.07))
            )
    }
}

private struct MetricCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        .background(
            Color.white.opacity(0.055),
            in: RoundedRectangle(cornerRadius: 15)
        )
    }
}

private struct CompactActionButton: View {
    let title: String
    let icon: String
    let primary: Bool
    let busy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(primary ? Color.black : Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(background)
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .opacity(busy ? 0.7 : 1)
    }

    @ViewBuilder
    private var background: some View {
        if primary {
            LinearGradient(
                colors: [.cyan, .green],
                startPoint: .leading,
                endPoint: .trailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 15))
        } else {
            Color.white.opacity(0.08)
                .clipShape(RoundedRectangle(cornerRadius: 15))
        }
    }
}

private struct RouteRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(.cyan)

            Text(title)
                .font(.system(size: 13))

            Spacer()

            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct SectionTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .bold))
    }
}

private struct CompactTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let secure: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Group {
                if secure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(.system(size: 13))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 11)
            .frame(height: 42)
            .background(
                Color.black.opacity(0.23),
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
    }
}

private struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.055, blue: 0.085),
                Color(red: 0.035, green: 0.09, blue: 0.13)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
