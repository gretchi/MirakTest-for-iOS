import Foundation

// Mirakurun API のうち、アプリで使用する部分のみを定義している
// https://github.com/Chinachu/Mirakurun/blob/master/api.d.ts

struct Channel: Codable, Hashable {
    var type: String
    var channel: String
    var name: String?
}

struct Service: Codable, Hashable, Identifiable {
    var id: Int
    var serviceId: Int
    var networkId: Int
    var name: String
    var type: Int
    var logoId: Int?
    var hasLogoData: Bool?
    var remoteControlKeyId: Int?
    var epgReady: Bool?
    var epgUpdatedAt: Int?
    var channel: Channel?

    /// デジタルTVサービス(0x01) / 超高精細度4K専用TVサービス(0xad)
    /// https://github.com/DBCTRADO/LibISDB/blob/ae14668bfc601d1b94851e666c82fe409afd8f31/LibISDB/LibISDBConsts.hpp#L122
    var isTVService: Bool {
        type == 0x01 || type == 0xad
    }
}

struct ProgramGenre: Codable, Hashable {
    var lv1: Int
    var lv2: Int
    var un1: Int?
    var un2: Int?
}

struct ProgramVideo: Codable, Hashable {
    var type: String?
    var resolution: String?
    var streamContent: Int?
    var componentType: Int?
}

struct ProgramAudio: Codable, Hashable {
    var componentType: Int?
    var componentTag: Int?
    var isMain: Bool?
    var samplingRate: Int?
    var langs: [String]?
}

struct Program: Codable, Hashable, Identifiable {
    var id: Int
    var eventId: Int
    var serviceId: Int
    var networkId: Int
    /// UNIX ミリ秒
    var startAt: Int64
    /// ミリ秒
    var duration: Int64
    var isFree: Bool?
    var name: String?
    var description: String?
    var genres: [ProgramGenre]?
    var video: ProgramVideo?
    var audios: [ProgramAudio]?
    var extended: ExtendedDescription?

    var startDate: Date { Date(timeIntervalSince1970: TimeInterval(startAt) / 1000) }

    /// duration が 1 の場合は終了時間未定
    var isEndUndetermined: Bool { duration == 1 }

    var endDate: Date {
        Date(timeIntervalSince1970: TimeInterval(startAt + (isEndUndetermined ? 0 : duration)) / 1000)
    }

    func isOnAir(at date: Date) -> Bool {
        if isEndUndetermined {
            return startDate <= date
        }
        return startDate <= date && date < endDate
    }

    /// 二ヶ国語放送 (デュアルモノ) かどうか
    var isDualMono: Bool {
        audios?.first?.componentType == 0x02
    }

    func belongs(to service: Service) -> Bool {
        serviceId == service.serviceId && networkId == service.networkId
    }
}

struct MirakurunStatus: Decodable {
    var version: String?
}

enum MirakurunCompatibility: String {
    case mirakurun = "Mirakurun"
    case mirakc = "mirakc"
    case mahiron = "Mahiron"
}

/// 番組の拡張形式イベント記述子。オブジェクトでない場合や値が文字列でない項目は無視する
/// (JSON のキー順は保持されないため、表示順は不定)
struct ExtendedDescription: Codable, Hashable {
    var items: [(key: String, value: String)]

    init(from decoder: Decoder) throws {
        guard let container = try? decoder.container(keyedBy: AnyKey.self) else {
            items = []
            return
        }
        items = container.allKeys.compactMap { key in
            guard let value = try? container.decode(String.self, forKey: key) else { return nil }
            return (key.stringValue, value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AnyKey.self)
        for item in items {
            try container.encode(item.value, forKey: AnyKey(stringValue: item.key)!)
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.items.elementsEqual(rhs.items) { $0.key == $1.key && $0.value == $1.value }
    }

    func hash(into hasher: inout Hasher) {
        for item in items {
            hasher.combine(item.key)
            hasher.combine(item.value)
        }
    }

    private struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue _: Int) { nil }
    }
}
