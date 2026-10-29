import Foundation
import Observation
import UIKit

/// Mirakurun との接続状態・サービス一覧・番組情報を保持する
/// デスクトップ版の MirakurunManager と main プロセスの EPGManager に相当する
@MainActor
@Observable
final class AppModel {
    enum ConnectionState: Equatable {
        case notConfigured
        case connecting
        case connected(MirakurunCompatibility, version: String?)
        case failed(String)
    }

    let settings: AppSettings
    let player: PlayerController

    private(set) var connectionState: ConnectionState = .notConfigured
    private(set) var services: [Service] = []
    private(set) var logos: [Int: UIImage] = [:]
    private(set) var lastEpgUpdated: Date?
    var selectedService: Service? {
        didSet {
            guard oldValue?.id != selectedService?.id else { return }
            playSelectedService()
        }
    }

    var isFullscreen = false

    /// "networkId-serviceId" をキーにした番組一覧 (開始時刻順)
    private var programsByService: [String: [Program]] = [:]
    private var client: MirakurunClient?
    private var epgRefreshTask: Task<Void, Never>?

    init(settings: AppSettings = AppSettings()) {
        self.settings = settings
        player = PlayerController(settings: settings)
    }

    // MARK: - 接続

    func connect() async {
        epgRefreshTask?.cancel()
        guard !settings.baseURL.isEmpty else {
            connectionState = .notConfigured
            return
        }
        let client: MirakurunClient
        do {
            client = try MirakurunClient(baseURLString: settings.baseURL, userAgent: AppSettings.userAgent)
        } catch {
            connectionState = .failed(error.localizedDescription)
            return
        }
        self.client = client
        connectionState = .connecting

        do {
            let (compatibility, version) = try await client.checkServer()
            let allServices = try await client.services()
            services = allServices.filter { !settings.isServiceTypeFilterEnabled || $0.isTVService }
            connectionState = .connected(compatibility, version: version)
        } catch {
            connectionState = .failed(error.localizedDescription)
            return
        }

        restoreSelectedService()
        await loadLogos(client: client)
        await refreshPrograms()

        epgRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60 * 10))
                await self?.refreshPrograms()
            }
        }
    }

    private func restoreSelectedService() {
        if let selectedService, let service = services.first(where: { $0.id == selectedService.id }) {
            self.selectedService = service
            return
        }
        // iPad など詳細画面が常に表示されるレイアウトでのみ、前回のサービスを自動で再生する
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
        selectedService = services.first(where: { $0.id == settings.lastServiceID }) ?? services.first
    }

    private func loadLogos(client: MirakurunClient) async {
        await withTaskGroup(of: (Int, UIImage?).self) { group in
            for service in services where service.hasLogoData == true {
                group.addTask {
                    let data = try? await client.logo(of: service)
                    return (service.id, data.flatMap(UIImage.init(data:)))
                }
            }
            for await (id, image) in group {
                if let image {
                    logos[id] = image
                }
            }
        }
    }

    func refreshPrograms() async {
        guard let client else { return }
        do {
            let programs = try await client.programs()
            var grouped = [String: [Program]]()
            for program in programs where program.name?.isEmpty == false {
                grouped[Self.key(networkId: program.networkId, serviceId: program.serviceId), default: []].append(program)
            }
            for key in grouped.keys {
                grouped[key]!.sort { $0.startAt < $1.startAt }
            }
            programsByService = grouped
            lastEpgUpdated = Date()
            player.currentProgram = selectedService.flatMap { currentProgram(of: $0, at: Date()) }
        } catch {
            print("番組情報の取得に失敗しました: \(error)")
        }
    }

    // MARK: - 番組情報

    private static func key(networkId: Int, serviceId: Int) -> String {
        "\(networkId)-\(serviceId)"
    }

    func programs(of service: Service) -> [Program] {
        programsByService[Self.key(networkId: service.networkId, serviceId: service.serviceId)] ?? []
    }

    func currentProgram(of service: Service, at date: Date) -> Program? {
        programs(of: service).last { $0.isOnAir(at: date) }
    }

    func nextProgram(of service: Service, at date: Date) -> Program? {
        programs(of: service).first { date < $0.startDate }
    }

    func service(of program: Program) -> Service? {
        services.first { program.belongs(to: $0) }
    }

    /// 番組表で表示可能な日付 (番組情報が存在する日の 0 時)
    var availableDays: [Date] {
        let calendar = Calendar.current
        let days = Set(programsByService.values.joined().map { calendar.startOfDay(for: $0.startDate) })
        let today = calendar.startOfDay(for: Date())
        return days.filter { today <= $0 }.sorted()
    }

    // MARK: - 再生

    private func playSelectedService() {
        guard let service = selectedService, let client else {
            player.stop()
            return
        }
        settings.lastServiceID = service.id
        player.currentProgram = currentProgram(of: service, at: Date())
        player.play(url: client.streamURL(of: service), service: service)
    }

    /// 前後のサービスに切り替える
    func switchService(offset: Int) {
        guard !services.isEmpty else { return }
        let index = selectedService.flatMap { current in services.firstIndex { $0.id == current.id } } ?? 0
        let next = (index + offset + services.count) % services.count
        selectedService = services[next]
    }

    /// 1 分毎に呼ばれ、再生中サービスの現在番組を更新する
    func tick(now: Date) {
        guard let service = selectedService else { return }
        let program = currentProgram(of: service, at: now)
        if player.currentProgram != program {
            player.currentProgram = program
        }
    }
}
