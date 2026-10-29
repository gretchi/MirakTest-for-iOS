import Foundation
import Observation

/// UserDefaults に永続化される設定値
/// デスクトップ版の src/types/setting.ts のうち iOS で意味を持つものを持つ
@Observable
final class AppSettings {
    private enum Key {
        static let baseURL = "mirakurun.baseUrl"
        static let isServiceTypeFilterEnabled = "mirakurun.isEnableServiceTypeFilter"
        static let networkCaching = "experimental.vlcNetworkCaching"
        static let isHardwareDecodingEnabled = "experimental.isVlcAvCodecHwAny"
        static let isDualMonoAutoAdjustEnabled = "experimental.isDualMonoAutoAdjustEnabled"
        static let lastServiceID = "contentPlayer.lastServiceId"
    }

    private let defaults: UserDefaults

    var baseURL: String {
        didSet { defaults.set(baseURL, forKey: Key.baseURL) }
    }

    var isServiceTypeFilterEnabled: Bool {
        didSet { defaults.set(isServiceTypeFilterEnabled, forKey: Key.isServiceTypeFilterEnabled) }
    }

    /// VLC の --network-caching (ミリ秒)。0 以下なら VLC の既定値を使う
    var networkCaching: Int {
        didSet { defaults.set(networkCaching, forKey: Key.networkCaching) }
    }

    var isHardwareDecodingEnabled: Bool {
        didSet { defaults.set(isHardwareDecodingEnabled, forKey: Key.isHardwareDecodingEnabled) }
    }

    /// 二ヶ国語放送の番組で自動的に主音声 (左) を選択する
    var isDualMonoAutoAdjustEnabled: Bool {
        didSet { defaults.set(isDualMonoAutoAdjustEnabled, forKey: Key.isDualMonoAutoAdjustEnabled) }
    }

    var lastServiceID: Int? {
        didSet { defaults.set(lastServiceID, forKey: Key.lastServiceID) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.isServiceTypeFilterEnabled: true,
            Key.networkCaching: 0,
            Key.isHardwareDecodingEnabled: true,
            Key.isDualMonoAutoAdjustEnabled: true,
        ])
        baseURL = defaults.string(forKey: Key.baseURL) ?? ""
        isServiceTypeFilterEnabled = defaults.bool(forKey: Key.isServiceTypeFilterEnabled)
        networkCaching = max(defaults.integer(forKey: Key.networkCaching), 0)
        isHardwareDecodingEnabled = defaults.bool(forKey: Key.isHardwareDecodingEnabled)
        isDualMonoAutoAdjustEnabled = defaults.bool(forKey: Key.isDualMonoAutoAdjustEnabled)
        lastServiceID = defaults.object(forKey: Key.lastServiceID) as? Int
    }

    static var userAgent: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        return "MirakTest/\(version) (iOS)"
    }
}
