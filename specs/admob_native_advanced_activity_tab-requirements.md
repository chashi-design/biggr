# AdMob ネイティブアドバンス表示仕様（アクティビティタブ）

## 目的
- アクティビティタブの情報量を損なわず、自然に広告を挿入する
- 既存の操作導線（活動記録/種目割合）の体験を壊さない

## 画面・配置
- 対象: アクティビティタブ（OverviewTabView）
- 挿入位置: 活動記録カード（OverviewActivityRecordCard）と種目割合カード（OverviewMuscleGroupShareCard）の間
- 表示数: 1枠のみ
- 表示条件: 広告ロード成功時のみ表示。失敗時は非表示で余白を詰める
- 表示タイミング: 画面表示時に1回ロード。再ロードは「アプリ復帰」または「画面再表示」のみ（過剰な再ロードは禁止）

## SDK / 設定要件
- Google Mobile Ads SDK を利用（導入前に承認が必要）
- AdMob アプリIDを Info.plist の GADApplicationIdentifier に設定
- 広告ユニットID
  - Debug: AdMob 提供のテストIDを使用
  - Release: 本番用IDを使用
- テスト端末IDを requestConfiguration.testDeviceIdentifiers に設定
- SKAdNetworkItems は Google 公式リストを反映
- IDFA を利用する場合は NSUserTrackingUsageDescription を追加し、ATTrackingManager で許諾を取得
- iOS 17 の PrivacyInfo.xcprivacy が必要な場合は追加
- GDPR/CCPA 対象地域に配信する場合は同意フローを検討（追加SDK導入は要承認）

## 実装方針（SwiftUI）
- UIViewRepresentable で GADNativeAdView をラップした NativeAdView を用意
- GADAdLoader（GADAdLoaderAdType.native）で広告を取得し、GADNativeAdLoaderDelegate で受信
- 受信した GADNativeAd を GADNativeAdView の各アセットへ割り当てる
- UI 更新は必ずメインスレッドで実行
- 広告のクリックは GADNativeAdView に任せ、Button や NavigationLink で包まない

## UI / レイアウト仕様
- 既存カードに近い見た目（角丸・余白）で統一
- 横幅: ScrollView の横余白に合わせてフル幅
- 高さ: メディア表示が崩れない最低高を確保（目安 120pt 以上）
- 必須アセット
  - Headline
  - MediaView
  - AdChoices
- 取得できたアセットのみ表示（Body/Icon/CTA/Rating など）
- 「広告」ラベルを明示して誤認を防止
- CTA ボタンは AccentColor（systemBlue）を基準に視認性を確保

## 触覚 / ナビゲーション
- 広告表示部に触覚FBは付けない
- 既存の遷移用FBトリガーを変更しない

## エラー / フォールバック
- ロード失敗時は表示しない（空白を残さない）
- 連続失敗時はログを最小限に留める（スパム防止）

## テスト観点
- Debug ではテストIDのみで表示されること
- iPhone SE 〜 Pro Max でレイアウト崩れがない
- 日本語/英語の両ロケールで表示確認
- タップ時に正しい遷移が起き、アプリ側遷移が発火しない

## 実装タスク分解
1. 仕様承認
   - AdMob SDK導入の承認
   - 本番/テストの広告ユニットID確定
   - IDFA利用の有無と同意フロー方針の確定
2. SDK導入・プロジェクト設定
   - Google Mobile Ads SDK を追加（SPMなど）
   - Info.plist に GADApplicationIdentifier を追加
   - SKAdNetworkItems / PrivacyInfo.xcprivacy / NSUserTrackingUsageDescription を必要に応じて反映
   - テスト端末IDを requestConfiguration.testDeviceIdentifiers に設定
3. 広告ローダーとView実装
   - GADAdLoader を持つ ObservableObject を用意し、ロード状態を管理
   - UIViewRepresentable で GADNativeAdView をラップし、アセットを安全に割り当て
   - 取得できたアセットのみ表示する構成を用意
4. Overview画面への組み込み
   - OverviewTabView の活動記録カードと種目割合カードの間に広告Viewを配置
   - ロード成功時のみ表示し、失敗時は余白を作らない
5. ライフサイクルとリロード方針
   - 画面初回表示で1回ロード
   - アプリ復帰 or 画面再表示で必要最小限の再ロード
6. 受け入れテスト
   - テストIDで広告が表示されること
   - タップ時にアプリ側の遷移や触覚FBが発火しないこと
   - 小型/大型端末でレイアウト崩れがないこと

## 関連ドキュメント
- 設計案: admob_native_advanced_activity_tab_design.md
