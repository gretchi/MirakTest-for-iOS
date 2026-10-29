import SwiftUI

/// 設定画面
/// デスクトップ版の windows/Settings.tsx に相当する
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var baseURL = ""
    @State private var isServiceTypeFilterEnabled = true

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                Section {
                    TextField("http://192.168.0.10:40772/api", text: $baseURL)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Toggle("TV サービスのみ表示する", isOn: $isServiceTypeFilterEnabled)
                    connectionStatus
                } header: {
                    Text("Mirakurun")
                } footer: {
                    Text("Mirakurun / mirakc の API の URL を入力してください。")
                }

                Section {
                    Toggle("ハードウェアデコードを使用する", isOn: $settings.isHardwareDecodingEnabled)
                    Stepper(value: $settings.networkCaching, in: -1 ... 10000, step: 250) {
                        LabeledContent("ネットワークキャッシュ", value: settings.networkCaching <= 0 ? "既定" : "\(settings.networkCaching) ms")
                    }
                    Toggle("二ヶ国語放送で主音声を自動選択する", isOn: $settings.isDualMonoAutoAdjustEnabled)
                } header: {
                    Text("再生")
                } footer: {
                    Text("ハードウェアデコードとネットワークキャッシュの変更は、次にサービスを切り替えたときに反映されます。")
                }

                Section("情報") {
                    LabeledContent("バージョン", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                    Link("GitHub", destination: URL(string: "https://github.com/ci7lus/MirakTest")!)
                    Text("本アプリに CAS 処理は含まれていないため、デコードされていない放送データを視聴することは出来ません。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存して接続") {
                        save()
                    }
                    .disabled(baseURL.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                baseURL = settings.baseURL
                isServiceTypeFilterEnabled = settings.isServiceTypeFilterEnabled
            }
        }
    }

    @ViewBuilder
    private var connectionStatus: some View {
        switch model.connectionState {
        case .notConfigured:
            LabeledContent("状態", value: "未設定")
        case .connecting:
            LabeledContent("状態") { ProgressView() }
        case let .connected(compatibility, version):
            LabeledContent("状態", value: "\(compatibility.rawValue) \(version ?? "") に接続済み")
        case let .failed(message):
            LabeledContent("状態") {
                Text(message).foregroundStyle(.red)
            }
        }
    }

    private func save() {
        settings.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.isServiceTypeFilterEnabled = isServiceTypeFilterEnabled
        Task {
            await model.connect()
            if case .connected = model.connectionState {
                dismiss()
            }
        }
    }
}
