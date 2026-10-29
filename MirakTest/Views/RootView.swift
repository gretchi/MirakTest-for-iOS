import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    @State private var columnVisibility = NavigationSplitViewVisibility.automatic
    @State private var isSettingsPresented = false
    @State private var isProgramTablePresented = false

    var body: some View {
        @Bindable var model = model

        NavigationSplitView(columnVisibility: $columnVisibility) {
            ServiceListView(selection: $model.selectedService)
                .navigationTitle("MirakTest")
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            isProgramTablePresented = true
                        } label: {
                            Label("番組表", systemImage: "calendar")
                        }
                        Button {
                            isSettingsPresented = true
                        } label: {
                            Label("設定", systemImage: "gearshape")
                        }
                    }
                }
        } detail: {
            if model.selectedService != nil {
                PlayerScreen()
            } else {
                ContentUnavailableView("サービスを選択してください", systemImage: "tv", description: Text("左の一覧から視聴するサービスを選択します"))
            }
        }
        .onChange(of: model.isFullscreen) { _, isFullscreen in
            withAnimation {
                columnVisibility = isFullscreen ? .detailOnly : .automatic
            }
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
        }
        .fullScreenCover(isPresented: $isProgramTablePresented) {
            ProgramTableView()
        }
        .task {
            await model.connect()
            if case .notConfigured = model.connectionState {
                isSettingsPresented = true
            }
        }
        .task {
            // 再生中番組の切り替わりを反映する
            while !Task.isCancelled {
                model.tick(now: Date())
                try? await Task.sleep(for: .seconds(30))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // バックグラウンドから復帰した時点で切断されていれば再接続する
            if phase == .active, model.player.status == .error {
                model.player.reload()
            }
        }
    }
}
