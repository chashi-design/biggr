import SwiftUI

// 共通の「行全体がスワイプ可能」なコンポーネント
struct SwipeDeleteRow<Content: View>: View {
    let label: String
    let allowsFullSwipe: Bool
    let action: () -> Void
    @ViewBuilder var content: Content

    init(
        label: String = "削除",
        allowsFullSwipe: Bool = true,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self.allowsFullSwipe = allowsFullSwipe
        self.action = action
        self.content = content()
    }

    var body: some View {
        content
            .contentShape(Rectangle())
            .trailingDeleteSwipe(allowsFullSwipe: allowsFullSwipe, label: label, action: action)
    }
}
