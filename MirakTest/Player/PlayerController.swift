import AVFoundation
import Observation
import UIKit
import VLCKitSPM

/// MobileVLCKit をラップしたプレイヤー
/// デスクトップ版の WebChimera.js (src/main/preload.ts) と VideoPlayer.tsx に相当する
@Observable
final class PlayerController: NSObject {
    struct Track: Identifiable, Hashable {
        var id: Int32
        var name: String
    }

    /// libvlc_audio_output_channel_t と同じ値
    enum AudioChannel: Int32, CaseIterable, Identifiable {
        case stereo = 1
        case reverseStereo = 2
        case left = 3
        case right = 4
        case dolby = 5

        var id: Int32 { rawValue }

        var label: String {
            switch self {
            case .stereo: return "ステレオ"
            case .reverseStereo: return "反転ステレオ"
            case .left: return "左 (主音声)"
            case .right: return "右 (副音声)"
            case .dolby: return "ドルビーサラウンド"
            }
        }
    }

    enum Status: Equatable {
        case idle
        case opening
        case buffering
        case playing
        case paused
        case error
    }

    private let settings: AppSettings
    @ObservationIgnored private var mediaPlayer: VLCMediaPlayer
    @ObservationIgnored private var appliedOptions: [String] = []
    @ObservationIgnored private weak var drawableView: UIView?
    @ObservationIgnored private var pendingSnapshotPath: String?

    private(set) var status: Status = .idle
    private(set) var service: Service?
    private(set) var audioTracks: [Track] = []
    private(set) var subtitleTracks: [Track] = []
    private(set) var currentAudioTrack: Int32 = -1
    private(set) var currentSubtitleTrack: Int32 = -1
    private(set) var audioChannel: AudioChannel = .stereo
    private(set) var lastSnapshot: UIImage?

    var isSubtitleEnabled = false {
        didSet { applySubtitleSelection() }
    }

    var isMuted = false {
        didSet { mediaPlayer.audio?.isMuted = isMuted }
    }

    /// 0...100
    var volume: Double = 100 {
        didSet { mediaPlayer.audio?.volume = Int32(volume) }
    }

    var currentProgram: Program? {
        didSet {
            guard oldValue?.id != currentProgram?.id else { return }
            adjustAudioChannelForProgram()
        }
    }

    var isPlaying: Bool { status == .playing }

    init(settings: AppSettings) {
        self.settings = settings
        let options = Self.libraryOptions(settings: settings)
        appliedOptions = options
        mediaPlayer = VLCMediaPlayer(options: options)
        super.init()
        mediaPlayer.delegate = self
        configureAudioSession()
    }

    private static func libraryOptions(settings: AppSettings) -> [String] {
        var options = [
            "--avcodec-hw=\(settings.isHardwareDecodingEnabled ? "any" : "none")",
            "--http-user-agent=\(AppSettings.userAgent)",
        ]
        if 0 < settings.networkCaching {
            options.append("--network-caching=\(settings.networkCaching)")
        }
        return options
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        } catch {
            print("AVAudioSession の設定に失敗しました: \(error)")
        }
    }

    /// 設定が変わっていれば libVLC のインスタンスを作り直す
    private func recreatePlayerIfNeeded() {
        let options = Self.libraryOptions(settings: settings)
        guard options != appliedOptions else { return }
        mediaPlayer.delegate = nil
        mediaPlayer.stop()
        appliedOptions = options
        mediaPlayer = VLCMediaPlayer(options: options)
        mediaPlayer.delegate = self
        mediaPlayer.drawable = drawableView
    }

    func attach(to view: UIView) {
        drawableView = view
        mediaPlayer.drawable = view
    }

    func detach(from view: UIView) {
        guard drawableView === view else { return }
        drawableView = nil
        mediaPlayer.drawable = nil
    }

    // MARK: - 再生操作

    func play(url: URL, service: Service) {
        recreatePlayerIfNeeded()
        self.service = service
        audioTracks = []
        subtitleTracks = []
        currentAudioTrack = -1
        currentSubtitleTrack = -1
        status = .opening

        try? AVAudioSession.sharedInstance().setActive(true)
        mediaPlayer.media = VLCMedia(url: url)
        mediaPlayer.play()
        mediaPlayer.audio?.volume = Int32(volume)
        mediaPlayer.audio?.isMuted = isMuted
    }

    func stop() {
        mediaPlayer.stop()
        mediaPlayer.media = nil
        service = nil
        status = .idle
    }

    func togglePause() {
        if mediaPlayer.isPlaying {
            mediaPlayer.pause()
        } else {
            mediaPlayer.play()
        }
    }

    /// 停止中のストリームを再接続する (ライブなので一時停止後の再開は遅延が大きくなるため)
    func reload() {
        guard let media = mediaPlayer.media, let url = media.url, let service else { return }
        mediaPlayer.stop()
        play(url: url, service: service)
    }

    func selectAudioTrack(_ track: Track) {
        mediaPlayer.currentAudioTrackIndex = track.id
        currentAudioTrack = track.id
    }

    func selectAudioChannel(_ channel: AudioChannel) {
        mediaPlayer.audioChannel = channel.rawValue
        audioChannel = channel
    }

    func selectSubtitleTrack(_ track: Track) {
        currentSubtitleTrack = track.id
        isSubtitleEnabled = true
    }

    private func applySubtitleSelection() {
        if isSubtitleEnabled {
            if currentSubtitleTrack < 0 {
                currentSubtitleTrack = subtitleTracks.first?.id ?? -1
            }
            mediaPlayer.currentVideoSubTitleIndex = currentSubtitleTrack
        } else {
            mediaPlayer.currentVideoSubTitleIndex = -1
        }
    }

    private func adjustAudioChannelForProgram() {
        guard settings.isDualMonoAutoAdjustEnabled, let program = currentProgram else { return }
        if program.isDualMono {
            if audioChannel == .stereo {
                selectAudioChannel(.left)
            }
        } else if audioChannel == .left || audioChannel == .right {
            selectAudioChannel(.stereo)
        }
    }

    // MARK: - スクリーンショット

    func takeSnapshot() {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("miraktest-\(UUID().uuidString).png").path
        pendingSnapshotPath = path
        // 幅・高さ 0 で元の解像度
        mediaPlayer.saveVideoSnapshot(at: path, withWidth: 0, andHeight: 0)
    }

    private func handleSnapshot() {
        guard let path = pendingSnapshotPath else { return }
        pendingSnapshotPath = nil
        guard let image = UIImage(contentsOfFile: path) else { return }
        try? FileManager.default.removeItem(atPath: path)
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        lastSnapshot = image
    }

    func clearLastSnapshot() {
        lastSnapshot = nil
    }

    // MARK: - トラック情報

    private func refreshTracks() {
        audioTracks = Self.tracks(names: mediaPlayer.audioTrackNames, indexes: mediaPlayer.audioTrackIndexes)
            .filter { $0.id >= 0 }
        subtitleTracks = Self.tracks(names: mediaPlayer.videoSubTitlesNames, indexes: mediaPlayer.videoSubTitlesIndexes)
            .filter { $0.id >= 0 }
        currentAudioTrack = mediaPlayer.currentAudioTrackIndex
        if isSubtitleEnabled, mediaPlayer.currentVideoSubTitleIndex < 0, !subtitleTracks.isEmpty {
            applySubtitleSelection()
        } else if !isSubtitleEnabled, mediaPlayer.currentVideoSubTitleIndex >= 0 {
            // VLC が自動的に字幕を有効化した場合は無効化する
            mediaPlayer.currentVideoSubTitleIndex = -1
        }
        let channel = AudioChannel(rawValue: mediaPlayer.audioChannel)
        if let channel, channel != audioChannel {
            // 番組切り替え時など VLC 側でリセットされた場合は選択中のチャンネルを再適用する
            mediaPlayer.audioChannel = audioChannel.rawValue
        }
    }

    private static func tracks(names: [Any], indexes: [Any]) -> [Track] {
        zip(names, indexes).compactMap { name, index in
            guard let index = (index as? NSNumber)?.int32Value else { return nil }
            return Track(id: index, name: name as? String ?? "トラック \(index)")
        }
    }
}

extension PlayerController: VLCMediaPlayerDelegate {
    func mediaPlayerStateChanged(_: Notification) {
        switch mediaPlayer.state {
        case .opening:
            status = .opening
        case .buffering:
            // 再生中にも buffering が通知されるため、isPlaying を優先する
            status = mediaPlayer.isPlaying ? .playing : .buffering
        case .playing:
            status = .playing
            // 音声出力は再生開始後に生成されるため、ここで改めて適用する
            mediaPlayer.audio?.volume = Int32(volume)
            mediaPlayer.audio?.isMuted = isMuted
            refreshTracks()
        case .paused:
            status = .paused
        case .esAdded:
            refreshTracks()
        case .error:
            status = .error
        case .ended:
            // ライブストリームが切断された場合
            if service != nil {
                status = .error
            }
        case .stopped:
            // サービス切り替え時に旧メディアの停止が遅れて通知されるため、状態は変更しない
            break
        @unknown default:
            break
        }
    }

    func mediaPlayerSnapshot(_: Notification) {
        handleSnapshot()
    }
}
