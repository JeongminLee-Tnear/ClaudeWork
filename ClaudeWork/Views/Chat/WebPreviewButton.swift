import SwiftUI
import WebKit

/// localhost URL을 감지해 "결과 보기" 버튼을 표시하고,
/// 클릭하면 앱 내 웹뷰로 미리보기를 제공한다.
struct WebPreviewButton: View {
    let messages: [ChatMessage]
    @State private var showPreview = false
    @State private var previewURL: URL?

    var body: some View {
        if let url = detectedURL {
            Button {
                previewURL = url
                showPreview = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                    Text("결과 보기")
                    Text(url.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .sheet(isPresented: $showPreview) {
                if let url = previewURL {
                    WebPreviewSheet(url: url)
                }
            }
        }
    }

    /// 메시지에서 localhost URL을 자동 감지
    private var detectedURL: URL? {
        let allText = messages.map { $0.content }.joined(separator: "\n")
        // localhost 또는 127.0.0.1 URL 패턴
        let pattern = #"https?://(?:localhost|127\.0\.0\.1):\d{2,5}[/\w.-]*"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: allText, range: NSRange(allText.startIndex..., in: allText)),
              let range = Range(match.range, in: allText) else {
            return nil
        }
        return URL(string: String(allText[range]))
    }
}

// MARK: - Web Preview Sheet

struct WebPreviewSheet: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "globe")
                    .foregroundStyle(Color.accentColor)

                Text(url.absoluteString)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                }
                .buttonStyle(.borderless)
                .help("브라우저에서 열기")

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .help("닫기")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Web View
            WebViewWrapper(url: url, isLoading: $isLoading)
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

// MARK: - WebView Wrapper

struct WebViewWrapper: NSViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebViewWrapper

        init(_ parent: WebViewWrapper) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Task { @MainActor in parent.isLoading = true }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in parent.isLoading = false }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in parent.isLoading = false }
        }
    }
}

#Preview {
    WebPreviewButton(messages: [
        ChatMessage(role: .assistant, content: "서버를 시작했습니다. http://localhost:3000 에서 확인하세요."),
    ])
    .padding()
}
