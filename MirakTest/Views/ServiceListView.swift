import SwiftUI

struct ServiceListView: View {
    @Environment(AppModel.self) private var model
    @Binding var selection: Service?

    var body: some View {
        List(selection: $selection) {
            connectionSection
            ForEach(groupedServices, id: \.type) { group in
                Section(group.type) {
                    ForEach(group.services) { service in
                        NavigationLink(value: service) {
                            ServiceRow(service: service)
                        }
                    }
                }
            }
        }
        .refreshable {
            await model.connect()
        }
    }

    @ViewBuilder
    private var connectionSection: some View {
        switch model.connectionState {
        case .notConfigured:
            Section {
                Label("Mirakurun の設定が行われていません。設定画面から設定を行ってください。", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            }
        case .connecting:
            Section {
                HStack {
                    ProgressView()
                    Text("接続中…").foregroundStyle(.secondary)
                }
            }
        case let .failed(message):
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Mirakurun への接続に失敗しました", systemImage: "wifi.exclamationmark")
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
                Button("再接続") {
                    Task { await model.connect() }
                }
            }
        case .connected:
            EmptyView()
        }
    }

    /// 地上波・BS・CS などのチャンネル種別ごとにまとめる
    private var groupedServices: [(type: String, services: [Service])] {
        var order = [String]()
        var groups = [String: [Service]]()
        for service in model.services {
            let type = service.channel?.type ?? "その他"
            if groups[type] == nil {
                order.append(type)
            }
            groups[type, default: []].append(service)
        }
        return order.map { ($0, groups[$0]!) }
    }
}

private struct ServiceRow: View {
    @Environment(AppModel.self) private var model
    let service: Service

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let program = model.currentProgram(of: service, at: context.date)
            HStack(spacing: 12) {
                ServiceLogo(service: service)
                VStack(alignment: .leading, spacing: 2) {
                    Text(service.name)
                        .font(.headline)
                        .lineLimit(1)
                    if let program {
                        Text(program.name ?? "")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if !program.isEndUndetermined {
                            ProgressView(value: progress(of: program, at: context.date))
                                .tint(.accentColor)
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func progress(of program: Program, at date: Date) -> Double {
        let total = program.endDate.timeIntervalSince(program.startDate)
        guard 0 < total else { return 0 }
        return min(max(date.timeIntervalSince(program.startDate) / total, 0), 1)
    }
}

struct ServiceLogo: View {
    @Environment(AppModel.self) private var model
    let service: Service

    var body: some View {
        Group {
            if let logo = model.logos[service.id] {
                Image(uiImage: logo)
                    .resizable()
                    .interpolation(.high)
            } else {
                Color.secondary.opacity(0.2)
                    .overlay {
                        Text(service.remoteControlKeyId.map(String.init) ?? "")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: 48, height: 27)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}
