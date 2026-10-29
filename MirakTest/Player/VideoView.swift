import SwiftUI
import UIKit

/// PlayerController が保持する VLC の描画ビューを表示するコンテナ
/// 全画面切り替えなどでこのビューが作り直されても、描画ビュー自体は付け替えるだけにする
struct VideoView: UIViewRepresentable {
    let player: PlayerController

    func makeUIView(context _: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black
        container.isUserInteractionEnabled = false
        return container
    }

    func updateUIView(_ container: UIView, context _: Context) {
        let videoView = player.videoView
        guard videoView.superview !== container else { return }
        videoView.removeFromSuperview()
        videoView.frame = container.bounds
        container.addSubview(videoView)
    }

    static func dismantleUIView(_ container: UIView, coordinator _: ()) {
        // 既に別のコンテナへ移っている場合は何もしない
        for subview in container.subviews {
            subview.removeFromSuperview()
        }
    }
}
