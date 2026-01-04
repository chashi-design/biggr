import SwiftUI

// 初回チュートリアル画面
struct TutorialView: View {
    @Binding var isPresented: Bool
    @State private var currentIndex = 0
    @State private var swipeFeedbackTrigger = 0
    @State private var isManualAdvance = false

    private var isJapaneseLocale: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }

    private var pages: [TutorialPage] {
        if isJapaneseLocale {
            return [
                TutorialPage(
                    title: "すばやく記録",
                    message: "カレンダーから日付を選んで、セットをすぐに追加できます。",
                    imageName: "TutorialLog"
                ),
                TutorialPage(
                    title: "種目を検索",
                    message: "検索やお気に入りで、よく使う種目に素早くアクセス。",
                    imageName: "TutorialSearch"
                ),
                TutorialPage(
                    title: "統計を確認",
                    message: "週・月のボリュームをチェックして成長を把握。",
                    imageName: "TutorialStats"
                ),
                TutorialPage(
                    title: "自分好みに",
                    message: "重量単位やリンク設定をいつでも変更できます。",
                    imageName: "TutorialSettings"
                )
            ]
        }

        return [
            TutorialPage(
                title: "Log in seconds",
                message: "Pick a date and add sets right from the calendar.",
                imageName: "TutorialLog"
            ),
            TutorialPage(
                title: "Find exercises fast",
                message: "Search and favorites keep frequent moves close.",
                imageName: "TutorialSearch"
            ),
            TutorialPage(
                title: "Track your stats",
                message: "Review weekly and monthly volume at a glance.",
                imageName: "TutorialStats"
            ),
            TutorialPage(
                title: "Make it yours",
                message: "Adjust units and links whenever you need.",
                imageName: "TutorialSettings"
            )
        ]
    }

    private var strings: TutorialStrings {
        TutorialStrings(isJapanese: isJapaneseLocale)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                TabView(selection: $currentIndex) {
                    ForEach(pages.indices, id: \.self) { index in
                        TutorialPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                PageIndicatorView(pageCount: pages.count, currentIndex: currentIndex)
                    .padding(.horizontal, 24)

                HapticButton {
                    handlePrimaryAction()
                } label: {
                    Text(primaryButtonTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 24)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(strings.title)
                        .font(.headline)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(currentIndex < pages.count - 1)
            .onChange(of: currentIndex) { _, _ in
                if isManualAdvance {
                    isManualAdvance = false
                } else {
                    swipeFeedbackTrigger += 1
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: swipeFeedbackTrigger)
        }
    }

    private var primaryButtonTitle: String {
        currentIndex == pages.count - 1 ? strings.startButtonTitle : strings.nextButtonTitle
    }

    private func handlePrimaryAction() {
        if currentIndex < pages.count - 1 {
            withAnimation(.easeInOut) {
                isManualAdvance = true
                currentIndex += 1
            }
        } else {
            isPresented = false
        }
    }
}

private struct TutorialPage {
    let title: String
    let message: String
    let imageName: String
}

private struct TutorialPageView: View {
    let page: TutorialPage

    var body: some View {
        VStack(spacing: 16) {
            Image(page.imageName)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 400)
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text(page.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 24)
    }
}

private struct PageIndicatorView: View {
    let pageCount: Int
    let currentIndex: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(currentIndex + 1) / \(pageCount)")
    }
}

private struct TutorialStrings {
    let isJapanese: Bool

    var title: String { isJapanese ? "チュートリアル" : "Tutorial" }
    var nextButtonTitle: String { isJapanese ? "次へ" : "Next" }
    var startButtonTitle: String { isJapanese ? "始める" : "Get Started" }
}

#Preview {
    TutorialView(isPresented: .constant(true))
}
