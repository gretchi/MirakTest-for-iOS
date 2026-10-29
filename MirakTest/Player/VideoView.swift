import SwiftUI
import UIKit

/// VLC の描画先となる UIView
struct VideoView: UIViewRepresentable {
    let player: PlayerController

    func makeCoordinator() -> PlayerController {
        player
    }

    func makeUIView(context _: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        view.isUserInteractionEnabled = false
        player.attach(to: view)
        return view
    }

    func updateUIView(_: UIView, context _: Context) {}

    static func dismantleUIView(_ uiView: UIView, coordinator: PlayerController) {
        coordinator.detach(from: uiView)
    }
}
