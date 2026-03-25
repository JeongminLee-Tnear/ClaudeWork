import SwiftUI
import Combine

struct PermissionModal: View {
    @Environment(AppState.self) private var appState
    let request: PermissionRequest

    @State private var remainingSeconds: Int = 300

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 20) {
            // Header
            headerSection

            Divider()

            // Details
            detailsSection

            Spacer()

            // Timer
            timerSection

            // Buttons
            buttonSection
        }
        .padding(24)
        .frame(width: 480, height: 380)
        .onReceive(timer) { _ in
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                Task { await appState.respondToPermission(request, decision: .deny) }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForRisk)
                .font(.title)
                .foregroundStyle(colorForRisk)

            VStack(alignment: .leading, spacing: 4) {
                Text("권한 요청")
                    .font(.title3)
                    .fontWeight(.semibold)

                HStack(spacing: 6) {
                    Text(request.toolName)
                        .font(.headline)

                    riskBadge
                }
            }

            Spacer()
        }
    }

    private var riskBadge: some View {
        Text(request.riskLevel.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(colorForRisk.opacity(0.15), in: Capsule())
            .foregroundStyle(colorForRisk)
    }

    // MARK: - Details

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Show command or file path based on tool type
            switch request.toolName.lowercased() {
            case "bash", "execute":
                detailRow(label: "명령어", value: extractString("command"))
            case "edit", "write", "multiedit", "multi_edit":
                detailRow(label: "파일", value: extractString("file_path"))
            default:
                detailRow(label: "입력", value: inputSummary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView {
                Text(value)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 120)
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Timer

    private var timerSection: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("자동 거부까지 \(formattedTime)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Buttons

    private var buttonSection: some View {
        HStack(spacing: 12) {
            Button("거부") {
                Task { await appState.respondToPermission(request, decision: .deny) }
            }
            .keyboardShortcut(.escape)
            .controlSize(.large)

            Spacer()

            Button("허용") {
                Task { await appState.respondToPermission(request, decision: .allow) }
            }
            .keyboardShortcut(.return)
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Helpers

    private var colorForRisk: Color {
        switch request.riskLevel {
        case .safe: return .green
        case .moderate: return .orange
        case .high: return .red
        }
    }

    private var iconForRisk: String {
        switch request.riskLevel {
        case .safe: return "checkmark.shield"
        case .moderate: return "exclamationmark.shield"
        case .high: return "xmark.shield"
        }
    }

    private func extractString(_ key: String) -> String {
        if let value = request.toolInput[key] {
            if case .string(let s) = value { return s }
            return "\(value)"
        }
        return inputSummary
    }

    private var inputSummary: String {
        let pairs = request.toolInput.map { "\($0.key): \($0.value)" }
        return pairs.joined(separator: "\n")
    }
}

#Preview {
    PermissionModal(request: PermissionRequest(
        id: "test-1",
        toolName: "Bash",
        toolInput: ["command": .string("rm -rf /tmp/test")],
        runToken: "token"
    ))
    .environment(AppState())
}
