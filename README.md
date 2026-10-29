# MirakTest for iOS

[Mirakurun](https://github.com/Chinachu/Mirakurun) 用映像視聴アプリ実装研究資料の iOS / iPadOS 版です。<br />
[ci7lus/MirakTest](https://github.com/ci7lus/MirakTest) (Electron 版) をフォークし、SwiftUI と [MobileVLCKit](https://code.videolan.org/videolan/VLCKit) でネイティブに再実装しています。

## 概要

iPhone / iPad 上で Mirakurun (および mirakc / Mahiron) を利用しデジタル放送を視聴するアプリの実装を研究する目的で配布される研究資料です。本アプリに CAS 処理は含まれていないため、デコードされていない放送データを視聴することは出来ません。

## 機能

- サービス一覧（現在の番組と進捗）とライブ視聴
- iPhone では横向きで全画面表示、iPad ではサイドバーとプレイヤーの 2 カラム表示
- 映像上の縦スワイプ・ボタンでのサービス切り替え
- 音声トラック・音声チャンネルの切り替え（二ヶ国語放送での主音声自動選択）
- ARIB 字幕の表示
- スクリーンショット（写真ライブラリへ保存）
- 番組表・番組詳細
- バックグラウンドでの音声再生

Electron 版のプラグイン機能・マルチウィンドウには対応していません。

## 動作環境

- iOS / iPadOS 17 以降
- Xcode 16 以降

## ビルド

1. `MirakTest.xcodeproj` を Xcode で開きます（初回は Swift Package の [vlckit-spm](https://github.com/tylerjonesio/vlckit-spm) が取得されます）
2. ターゲット `MirakTest` の Signing & Capabilities で Team を設定します
3. 実機を選択して実行します

起動後、設定画面で Mirakurun の API の URL（例: `http://192.168.0.10:40772/api`）を入力してください。

## 構成

| パス | 内容 |
| --- | --- |
| `MirakTest/App` | エントリポイント、設定、アプリ全体の状態 (`AppModel`) |
| `MirakTest/Models` | Mirakurun API のモデル |
| `MirakTest/Services` | Mirakurun API クライアント |
| `MirakTest/Player` | MobileVLCKit のラッパーと描画ビュー |
| `MirakTest/Views` | サービス一覧・プレイヤー・番組表・設定の各画面 |
| `MirakTest/Utils` | ジャンル定義など |

## ライセンス

MIT License（[LICENSE](./LICENSE)）

### 謝辞

- [Mirakurun](https://github.com/Chinachu/Mirakurun)
- [VLCKit](https://code.videolan.org/videolan/VLCKit) / [vlckit-spm](https://github.com/tylerjonesio/vlckit-spm)
- ジャンル定義は [l3tnun/EPGStation](https://github.com/l3tnun/EPGStation) (MIT License) に由来します
