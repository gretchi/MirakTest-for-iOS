import SwiftUI

struct PlayerScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(PlayerController.self) private var player
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// iPhone の横向きでは映像のみを全画面表示する
    private var isFullscreen: Bool {
        verticalSizeClass == .compact || model.isFullscreen
    }

    var body: some View {
        Group {
            if isFullscreen {
                PlayerSurface(isFullscreen: true)
                    .ignoresSafeArea()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        PlayerSurface(isFullscreen: false)
                            .aspectRatio(16 / 9, contentMode: .fit)
                        ProgramInfoView()
                            .padding()
                    }
                }
            }
        }
        .background(isFullscreen ? Color.black : Color(uiColor: .systemBackground))
        .navigationTitle(model.selectedService?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isFullscreen ? .hidden : .automatic, for: .navigationBar)
        .statusBarHidden(isFullscreen)
        .persistentSystemOverlays(isFullscreen ? .hidden : .automatic)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}

/// 映像とその上に重なる操作パネル
private struct PlayerSurface: View {
    @Environment(AppModel.self) private var model
    @Environment(PlayerController.self) private var player
    let isFullscreen: Bool

    @State private var isControlsVisible = true
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black
            VideoView(player: player)
            statusOverlay
            if isControlsVisible {
                PlayerControls(isFullscreen: isFullscreen, onInteraction: scheduleHide)
                    .transition(.opacity)
            }
            SnapshotToast()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isControlsVisible.toggle()
            }
            if isControlsVisible {
                scheduleHide()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    // 縦方向のスワイプでサービスを切り替える
                    guard abs(value.translation.height) > abs(value.translation.width) else { return }
                    model.switchService(offset: value.translation.height < 0 ? 1 : -1)
                },
            // 縦スクロールする画面内では誤操作になるため、全画面表示時のみ有効にする
            including: isFullscreen ? .all : .subviews
        )
        .onAppear(perform: scheduleHide)
    }

    @ViewBuilder
    private var statusOverlay: some View {
        switch player.status {
        case .opening, .buffering:
            ProgressView()
                .controlSize(.large)
                .tint(.white)
        case .error:
            VStack(spacing: 12) {
                Text("再生できませんでした")
                    .foregroundStyle(.white)
                Button("再読み込み") {
                    player.reload()
                }
                .buttonStyle(.borderedProminent)
            }
        default:
            EmptyView()
        }
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled, player.isPlaying else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                isControlsVisible = false
            }
        }
    }
}

private struct PlayerControls: View {
    @Environment(AppModel.self) private var model
    @Environment(PlayerController.self) private var player
    let isFullscreen: Bool
    let onInteraction: () -> Void

    var body: some View {
        @Bindable var player = player

        VStack(spacing: 0) {
            // 上部: サービス名と番組名
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.selectedService?.name ?? "")
                        .font(.headline)
                    if let program = player.currentProgram {
                        Text(program.name ?? "")
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding()
            .background(LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom))

            Spacer()

            // 中央: 選局と再生/一時停止
            HStack(spacing: 48) {
                Button {
                    model.switchService(offset: -1)
                    onInteraction()
                } label: {
                    Image(systemName: "chevron.up.circle")
                }
                .accessibilityLabel("前のサービス")
                Button {
                    player.togglePause()
                    onInteraction()
                } label: {
                    Image(systemName: player.status == .paused ? "play.circle.fill" : "pause.circle.fill")
                        .font(.system(size: 56))
                }
                .accessibilityLabel(player.status == .paused ? "再生" : "一時停止")
                Button {
                    model.switchService(offset: 1)
                    onInteraction()
                } label: {
                    Image(systemName: "chevron.down.circle")
                }
                .accessibilityLabel("次のサービス")
            }
            .font(.system(size: 32))
            .opacity(player.status == .opening || player.status == .buffering ? 0 : 1)

            Spacer()

            // 下部: 音量・音声・字幕・スクリーンショット・全画面
            HStack(spacing: 16) {
                Button {
                    player.isMuted.toggle()
                    onInteraction()
                } label: {
                    Image(systemName: player.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                }
                .accessibilityLabel(player.isMuted ? "ミュート解除" : "ミュート")
                Slider(value: $player.volume, in: 0 ... 100) { editing in
                    if !editing { onInteraction() }
                }
                .frame(maxWidth: 160)

                Spacer()

                audioMenu
                subtitleButton
                Button {
                    player.takeSnapshot()
                    onInteraction()
                } label: {
                    Image(systemName: "camera")
                }
                .disabled(!player.isPlaying)
                .accessibilityLabel("スクリーンショット")
                if UIDevice.current.userInterfaceIdiom == .pad {
                    Button {
                        model.isFullscreen.toggle()
                    } label: {
                        Image(systemName: model.isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    }
                    .accessibilityLabel(model.isFullscreen ? "全画面表示を終了" : "全画面表示")
                }
            }
            .padding()
            .background(LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom))
        }
        .foregroundStyle(.white)
        .tint(.white)
        .font(.title3)
    }

    private var audioMenu: some View {
        Menu {
            if player.audioTracks.count > 1 {
                Section("音声トラック") {
                    ForEach(player.audioTracks) { track in
                        Button {
                            player.selectAudioTrack(track)
                        } label: {
                            if track.id == player.currentAudioTrack {
                                Label(track.name, systemImage: "checkmark")
                            } else {
                                Text(track.name)
                            }
                        }
                    }
                }
            }
            Section("音声チャンネル") {
                ForEach(PlayerController.AudioChannel.allCases) { channel in
                    Button {
                        player.selectAudioChannel(channel)
                    } label: {
                        if channel == player.audioChannel {
                            Label(channel.label, systemImage: "checkmark")
                        } else {
                            Text(channel.label)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "waveform")
        }
        .accessibilityLabel("音声")
        .simultaneousGesture(TapGesture().onEnded(onInteraction))
    }

    @ViewBuilder
    private var subtitleButton: some View {
        if player.subtitleTracks.count > 1 {
            Menu {
                Button {
                    player.isSubtitleEnabled = false
                } label: {
                    if !player.isSubtitleEnabled {
                        Label("オフ", systemImage: "checkmark")
                    } else {
                        Text("オフ")
                    }
                }
                ForEach(player.subtitleTracks) { track in
                    Button {
                        player.selectSubtitleTrack(track)
                    } label: {
                        if player.isSubtitleEnabled, track.id == player.currentSubtitleTrack {
                            Label(track.name, systemImage: "checkmark")
                        } else {
                            Text(track.name)
                        }
                    }
                }
            } label: {
                Image(systemName: player.isSubtitleEnabled ? "captions.bubble.fill" : "captions.bubble")
            }
            .accessibilityLabel("字幕")
            .simultaneousGesture(TapGesture().onEnded(onInteraction))
        } else {
            Button {
                player.isSubtitleEnabled.toggle()
                onInteraction()
            } label: {
                Image(systemName: player.isSubtitleEnabled ? "captions.bubble.fill" : "captions.bubble")
            }
            .accessibilityLabel(player.isSubtitleEnabled ? "字幕をオフ" : "字幕をオン")
        }
    }
}

/// スクリーンショットの保存結果を一時的に表示する
private struct SnapshotToast: View {
    @Environment(PlayerController.self) private var player

    var body: some View {
        if let result = player.snapshotResult {
            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        switch result {
                        case let .saved(image):
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            Text("写真に保存しました")
                                .font(.caption)
                                .foregroundStyle(.white)
                        case let .failed(message):
                            Label(message, systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(8)
                    .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                }
                Spacer()
            }
            .padding()
            .transition(.opacity)
            .task(id: result) {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                withAnimation {
                    player.clearSnapshotResult()
                }
            }
        }
    }
}

/// 再生中の番組情報
private struct ProgramInfoView: View {
    @Environment(AppModel.self) private var model
    @Environment(PlayerController.self) private var player

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let program = player.currentProgram {
                ProgramDetailContent(program: program)
            } else {
                Text("番組情報がありません")
                    .foregroundStyle(.secondary)
            }
            if let service = model.selectedService, let next = model.nextProgram(of: service, at: Date()) {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("次の番組")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(next.name ?? "")
                        .font(.subheadline.bold())
                    Text(ProgramDetailContent.timeRange(of: next))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
