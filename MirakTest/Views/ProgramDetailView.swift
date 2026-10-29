import SwiftUI

/// 番組の詳細 (番組名・時間・ジャンル・説明・拡張記述)
/// デスクトップ版の ProgramModal.tsx / SidebarServiceDetail.tsx に相当する
struct ProgramDetailContent: View {
    let program: Program

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(program.name ?? "")
                    .font(.title3.bold())
                    .textSelection(.enabled)
                Text(Self.timeRange(of: program))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let genres = program.genres, !genres.isEmpty {
                FlowTags(tags: genres.map { (Genre.label(of: $0), Genre.color(lv1: $0.lv1)) })
            }
            if let description = program.description, !description.isEmpty {
                Text(description)
                    .textSelection(.enabled)
            }
            if let extended = program.extended?.items, !extended.isEmpty {
                ForEach(extended, id: \.key) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.key)
                            .font(.subheadline.bold())
                        Text(item.value)
                            .font(.subheadline)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    static func timeRange(of program: Program) -> String {
        let start = program.startDate.formatted(.dateTime.month().day().weekday(.abbreviated).hour().minute())
        if program.isEndUndetermined {
            return "\(start) 〜 (終了時間未定)"
        }
        let end = program.endDate.formatted(.dateTime.hour().minute())
        let minutes = Int(program.duration / 1000 / 60)
        return "\(start) 〜 \(end) (\(minutes)分)"
    }
}

private struct FlowTags: View {
    let tags: [(String, Color)]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack { content }
            VStack(alignment: .leading) { content }
        }
    }

    private var content: some View {
        ForEach(tags, id: \.0) { tag in
            Text(tag.0)
                .font(.caption)
                .foregroundStyle(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(tag.1, in: Capsule())
        }
    }
}

/// 番組表から開く番組詳細シート
struct ProgramDetailSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let program: Program
    let onWatch: (Service) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let service = model.service(of: program) {
                        HStack {
                            ServiceLogo(service: service)
                            Text(service.name)
                                .font(.headline)
                        }
                    }
                    ProgramDetailContent(program: program)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("番組詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                if let service = model.service(of: program) {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("このサービスを視聴") {
                            onWatch(service)
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
