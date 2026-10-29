import SwiftUI

/// 番組表
/// デスクトップ版の windows/ProgramTable.tsx に相当する
struct ProgramTableView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// 深夜 0〜4 時は前日の番組表を開く
    @State private var selectedDay = AppModel.broadcastDay(of: Date())
    @State private var selectedProgram: Program?

    private static let dayStartHour = AppModel.broadcastDayStartHour

    private var hourHeight: CGFloat { horizontalSizeClass == .regular ? 200 : 160 }
    private var columnWidth: CGFloat { horizontalSizeClass == .regular ? 160 : 120 }
    private let timeColumnWidth: CGFloat = 28
    private let headerHeight: CGFloat = 44

    private var rangeStart: Date {
        Calendar.current.date(byAdding: .hour, value: Self.dayStartHour, to: selectedDay)!
    }

    private var rangeEnd: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: rangeStart)!
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.services.isEmpty {
                    ContentUnavailableView("番組情報がありません", systemImage: "calendar.badge.exclamationmark", description: Text("Mirakurun に接続されているか確認してください"))
                } else {
                    table
                }
            }
            .navigationTitle("番組表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    daySelector
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await model.refreshPrograms() }
                    } label: {
                        Label("更新", systemImage: "arrow.clockwise")
                    }
                }
            }
            .sheet(item: $selectedProgram) { program in
                ProgramDetailSheet(program: program) { service in
                    model.selectedService = service
                    selectedProgram = nil
                    dismiss()
                }
            }
        }
    }

    private var daySelector: some View {
        // 選択中の日付は必ず選択肢に含める (Picker の選択値が候補に無いと表示が崩れる)
        let days = Set(model.availableBroadcastDays + [selectedDay]).sorted()
        return Menu {
            Picker("日付", selection: $selectedDay) {
                ForEach(days, id: \.self) { day in
                    Text(day.formatted(.dateTime.month().day().weekday(.abbreviated))).tag(day)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedDay.formatted(.dateTime.month().day().weekday(.abbreviated)))
                    .font(.headline)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
        }
    }

    private var table: some View {
        ScrollViewReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            HStack(alignment: .top, spacing: 0) {
                                timeColumn
                                ForEach(model.services) { service in
                                    serviceColumn(service)
                                }
                            }
                            .overlay(alignment: .topLeading) { nowIndicator }
                        } header: {
                            serviceHeader
                        }
                    }
                }
                .onAppear { scrollToNow(proxy: proxy) }
                .onChange(of: selectedDay) { scrollToNow(proxy: proxy) }
        }
    }

    private func scrollToNow(proxy: ScrollViewProxy) {
        let now = Date()
        guard rangeStart <= now, now < rangeEnd else {
            proxy.scrollTo(hourID(0), anchor: .topLeading)
            return
        }
        let hour = Calendar.current.dateComponents([.hour], from: rangeStart, to: now).hour ?? 0
        proxy.scrollTo(hourID(max(hour - 1, 0)), anchor: .topLeading)
    }

    private func hourID(_ offset: Int) -> String {
        "hour-\(offset)"
    }

    private var serviceHeader: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: timeColumnWidth)
            ForEach(model.services) { service in
                HStack(spacing: 6) {
                    ServiceLogo(service: service, width: 36)
                    Text(service.name)
                        .font(.caption.bold())
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .padding(.horizontal, 4)
                .frame(width: columnWidth, height: headerHeight)
                .overlay(alignment: .trailing) { Divider() }
            }
        }
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var timeColumn: some View {
        VStack(spacing: 0) {
            ForEach(0 ..< 24, id: \.self) { offset in
                let hour = (Self.dayStartHour + offset) % 24
                Text("\(hour)")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(width: timeColumnWidth, height: hourHeight, alignment: .top)
                    .padding(.top, 4)
                    .background(hourColor(hour))
                    .overlay(alignment: .top) { Divider() }
                    .id(hourID(offset))
            }
        }
    }

    private func hourColor(_ hour: Int) -> Color {
        switch hour {
        case 4 ..< 12: return Color(red: 0.95, green: 0.55, blue: 0.4)
        case 12 ..< 18: return Color(red: 0.25, green: 0.6, blue: 0.85)
        default: return Color(red: 0.25, green: 0.3, blue: 0.55)
        }
    }

    private func serviceColumn(_ service: Service) -> some View {
        let programs = model.programs(of: service).filter { program in
            program.startDate < rangeEnd && (program.isEndUndetermined || rangeStart < program.endDate)
        }
        return ZStack(alignment: .topLeading) {
            Color(uiColor: .secondarySystemBackground)
            ForEach(programs) { program in
                let frame = programFrame(program)
                ProgramCell(program: program)
                    .frame(width: columnWidth, height: frame.height, alignment: .topLeading)
                    .offset(y: frame.minY)
                    .onTapGesture { selectedProgram = program }
            }
        }
        .frame(width: columnWidth, height: hourHeight * 24, alignment: .topLeading)
        .clipped()
        .overlay(alignment: .trailing) { Divider() }
    }

    private func programFrame(_ program: Program) -> CGRect {
        let start = max(program.startDate, rangeStart)
        // 終了時間未定の番組は 1 時間分の枠で表示する
        let end = min(program.isEndUndetermined ? program.startDate.addingTimeInterval(3600) : program.endDate, rangeEnd)
        let y = start.timeIntervalSince(rangeStart) / 3600 * hourHeight
        let height = max(end.timeIntervalSince(start) / 3600 * hourHeight, 1)
        return CGRect(x: 0, y: y, width: columnWidth, height: height)
    }

    @ViewBuilder
    private var nowIndicator: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            if rangeStart <= context.date, context.date < rangeEnd {
                let y = context.date.timeIntervalSince(rangeStart) / 3600 * hourHeight
                Rectangle()
                    .fill(.red)
                    .frame(width: timeColumnWidth + columnWidth * CGFloat(model.services.count), height: 2)
                    .offset(y: y)
                    .allowsHitTesting(false)
            }
        }
    }
}

private struct ProgramCell: View {
    let program: Program

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(program.startDate.formatted(.dateTime.minute(.twoDigits)))
                    .font(.caption2.bold().monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 2)
                    .background(Color.gray)
                Text(program.name ?? "")
                    .font(.caption.bold())
            }
            if let description = program.description {
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.black.opacity(0.7))
            }
        }
        .foregroundStyle(.black)
        .padding(3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Genre.color(lv1: program.genres?.first?.lv1))
        .overlay {
            Rectangle().stroke(Color.black.opacity(0.15), lineWidth: 0.5)
        }
        .clipped()
        .contentShape(Rectangle())
    }
}
