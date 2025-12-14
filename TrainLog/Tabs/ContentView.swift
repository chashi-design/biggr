import SwiftUI

// アプリ全体のタブをまとめるエントリーポイント
struct ContentView: View {
    var body: some View {
        TabView {
            OverviewTabView()
                .tabItem {
                    Label("概要", systemImage: "square.grid.2x2")
                }

            LogView()
                .tabItem {
                    Label("ログ", systemImage: "square.and.pencil")
                }

            HistoryView()
                .tabItem {
                    Label("履歴", systemImage: "clock.arrow.circlepath")
                }
        }
    }
}

#Preview {
    ContentView()
}
