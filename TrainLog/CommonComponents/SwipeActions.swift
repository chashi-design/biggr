import SwiftUI

// 共通のスワイプアクションデザイン
extension View {
    func trailingDeleteSwipe(
        allowsFullSwipe: Bool = true,
        label: String = "削除",
        action: @escaping () -> Void
    ) -> some View {
        swipeActions(edge: .trailing, allowsFullSwipe: allowsFullSwipe) {
            Button(role: .destructive) {
                action()
            } label: {
                Label(label, systemImage: "trash")
            }
        }
    }
}
