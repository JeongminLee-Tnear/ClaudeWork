import SwiftUI

/// 비개발자를 위한 Git 개념 가이드.
/// 디자이너가 알아야 할 핵심 개념을 시각적 비유와 함께 설명한다.
struct GitGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTopic: GitTopic = .overview

    var body: some View {
        NavigationSplitView {
            topicList
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            ScrollView {
                topicDetail(selectedTopic)
                    .padding(24)
                    .frame(maxWidth: 600, alignment: .leading)
            }
            .background(ClaudeTheme.background)
        }
        .frame(minWidth: 700, minHeight: 500)
    }

    // MARK: - Topic List

    private var topicList: some View {
        List(GitTopic.allCases, selection: $selectedTopic) { topic in
            Label(topic.title, systemImage: topic.icon)
                .foregroundStyle(ClaudeTheme.textPrimary)
                .tag(topic)
        }
        .listStyle(.sidebar)
        .navigationTitle("Git 가이드")
    }

    // MARK: - Topic Detail

    @ViewBuilder
    private func topicDetail(_ topic: GitTopic) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title
            HStack(spacing: 12) {
                Image(systemName: topic.icon)
                    .font(.title)
                    .foregroundStyle(ClaudeTheme.accent)
                Text(topic.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(ClaudeTheme.textPrimary)
            }

            ClaudeThemeDivider()

            // Analogy
            analogyCard(topic.analogy)

            // Explanation
            ForEach(Array(topic.sections.enumerated()), id: \.offset) { _, section in
                sectionView(section)
            }
        }
    }

    private func analogyCard(_ analogy: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(ClaudeTheme.accent)
                .font(.title3)

            Text(analogy)
                .font(.body)
                .foregroundStyle(ClaudeTheme.textPrimary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ClaudeTheme.accentSubtle)
        .clipShape(RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusMedium)
                .strokeBorder(ClaudeTheme.accent.opacity(0.3), lineWidth: 0.5)
        )
    }

    private func sectionView(_ section: GuideSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = section.title {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(ClaudeTheme.textPrimary)
            }

            Text(section.body)
                .font(.body)
                .foregroundStyle(ClaudeTheme.textSecondary)

            if let example = section.example {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(ClaudeTheme.accent.opacity(0.4))
                        .frame(width: 3)
                    Text(example)
                        .font(.callout)
                        .foregroundStyle(ClaudeTheme.textPrimary)
                }
                .padding(.leading, 4)
            }
        }
    }
}

// MARK: - Data

enum GitTopic: String, CaseIterable, Identifiable {
    case overview
    case repository
    case commit
    case branch
    case pushPull
    case pullRequest
    case merge
    case gitStatus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Git이 뭔가요?"
        case .repository: "레포지토리"
        case .commit: "커밋"
        case .branch: "브랜치"
        case .pushPull: "Push와 Pull"
        case .pullRequest: "Pull Request (PR)"
        case .merge: "머지"
        case .gitStatus: "Git 상태 읽기"
        }
    }

    var icon: String {
        switch self {
        case .overview: "questionmark.circle"
        case .repository: "folder.fill"
        case .commit: "camera.fill"
        case .branch: "arrow.triangle.branch"
        case .pushPull: "arrow.up.arrow.down"
        case .pullRequest: "text.bubble"
        case .merge: "arrow.triangle.merge"
        case .gitStatus: "eye"
        }
    }

    var analogy: String {
        switch self {
        case .overview:
            "피그마의 버전 히스토리와 비슷해요. 파일이 언제, 어떻게 바뀌었는지 전부 기록하는 시스템이에요."
        case .repository:
            "피그마 프로젝트 파일과 같아요. 디자인 파일, 에셋, 컴포넌트가 모두 한 곳에 들어있는 것처럼, 레포에는 코드 파일이 전부 담겨있어요."
        case .commit:
            "피그마에서 '버전 저장(Save to Version History)'을 누르는 것과 같아요. \"로고 색상 변경\" 같은 메모와 함께 현재 상태를 기록하는 거예요."
        case .branch:
            "피그마에서 페이지를 복제(Duplicate)해서 새로운 시도를 하는 것과 같아요. 원본은 그대로 두고, 사본에서 자유롭게 실험할 수 있어요."
        case .pushPull:
            "Push는 내 컴퓨터의 작업을 클라우드에 올리는 것, Pull은 클라우드의 최신 변경을 내 컴퓨터로 가져오는 것이에요. 피그마는 자동 동기화되지만, Git은 수동으로 해야 해요."
        case .pullRequest:
            "디자인 리뷰 요청과 같아요. \"이 디자인 확인해주세요\"라고 팀에 보내는 것처럼, 코드 변경사항을 팀에게 검토 요청하는 거예요."
        case .merge:
            "두 페이지의 작업을 하나로 합치는 것이에요. 내가 작업한 브랜치를 원본(main)에 반영하는 과정이에요."
        case .gitStatus:
            "피그마의 변경 표시(파란 점)와 비슷해요. 어떤 파일이 수정됐는지, 저장(커밋) 준비가 됐는지 알려줘요."
        }
    }

    var sections: [GuideSection] {
        switch self {
        case .overview:
            [
                GuideSection(
                    title: "왜 쓰나요?",
                    body: "여러 사람이 같은 코드를 동시에 수정할 수 있게 해주고, 실수했을 때 이전 상태로 돌아갈 수 있어요.",
                    example: nil
                ),
                GuideSection(
                    title: "Git vs GitHub",
                    body: "Git은 내 컴퓨터에서 돌아가는 버전 관리 프로그램이에요. GitHub는 Git으로 관리하는 코드를 인터넷에 올려두는 서비스예요. 피그마 앱(Git)과 피그마 클라우드(GitHub)의 관계와 같아요.",
                    example: nil
                ),
                GuideSection(
                    title: "잔디(Contributions)",
                    body: "GitHub 프로필에 보이는 초록색 칸이에요. 커밋을 하면 해당 날짜에 초록색이 채워져요. 매일 커밋하면 잔디밭이 빽빽해지는 거예요!",
                    example: "ClaudeWork 앱에서 Claude에게 작업을 시키고, 그 결과를 커밋하면 잔디가 심어져요."
                ),
            ]
        case .repository:
            [
                GuideSection(
                    title: "쉽게 말하면",
                    body: "프로젝트 폴더예요. 다만 일반 폴더와 달리, 모든 변경 히스토리가 함께 저장돼요.",
                    example: "ClaudeWork 앱에서 GitHub 레포를 클릭하면 자동으로 내 컴퓨터에 복사(clone)돼요."
                ),
                GuideSection(
                    title: "로컬 vs 리모트",
                    body: "로컬 레포는 내 컴퓨터에 있는 것, 리모트 레포는 GitHub에 올라가 있는 것이에요. 두 곳을 동기화하면서 작업해요.",
                    example: nil
                ),
            ]
        case .commit:
            [
                GuideSection(
                    title: "쉽게 말하면",
                    body: "\"현재 상태를 기록해둘게\"라는 의미예요. 커밋 메시지에는 뭘 바꿨는지 간단히 적어요.",
                    example: "\"로그인 버튼 색상 변경\" — 이렇게 무엇을 왜 바꿨는지 적으면 나중에 찾기 쉬워요."
                ),
                GuideSection(
                    title: "커밋 전에 해야 할 것: Stage (스테이지)",
                    body: "커밋하기 전에 \"이 파일을 포함시킬게\"라고 선택하는 과정이에요. 피그마에서 내보내기 전에 프레임을 선택하는 것과 비슷해요.",
                    example: "'git add 파일이름' = 이 파일을 다음 커밋에 포함시켜"
                ),
            ]
        case .branch:
            [
                GuideSection(
                    title: "쉽게 말하면",
                    body: "원본을 건드리지 않고 새로운 작업을 시작하는 방법이에요. 'main' 브랜치가 원본이고, 새 브랜치를 만들어서 작업해요.",
                    example: "main(원본) → feature/login-page(사본에서 작업) → 완성되면 main에 합치기"
                ),
                GuideSection(
                    title: "왜 브랜치를 쓰나요?",
                    body: "여러 기능을 동시에 개발할 수 있어요. A 기능과 B 기능을 각각 다른 브랜치에서 만들면, 서로 영향을 주지 않아요.",
                    example: nil
                ),
            ]
        case .pushPull:
            [
                GuideSection(
                    title: "Push (푸시)",
                    body: "내 컴퓨터의 커밋들을 GitHub에 올리는 것이에요. 동료들이 내 작업을 볼 수 있게 돼요.",
                    example: "'git push' = 내 작업을 GitHub에 올려!"
                ),
                GuideSection(
                    title: "Pull (풀)",
                    body: "GitHub에 있는 다른 사람의 변경사항을 내 컴퓨터로 가져오는 것이에요.",
                    example: "'git pull' = 팀원들의 최신 작업을 가져와!"
                ),
                GuideSection(
                    title: "Push vs PR의 차이",
                    body: "Push는 단순히 코드를 올리는 행위예요. PR(Pull Request)은 \"내가 올린 코드를 검토하고 합쳐주세요\"라는 요청이에요. Push한 다음에 PR을 만드는 순서예요.",
                    example: "1. 작업 → 2. 커밋 → 3. Push → 4. PR 생성 → 5. 팀 리뷰 → 6. 머지"
                ),
            ]
        case .pullRequest:
            [
                GuideSection(
                    title: "쉽게 말하면",
                    body: "\"이 변경사항을 확인해주세요\" 라는 팀 리뷰 요청이에요. 디자인 팀에서 시안을 공유하고 피드백 받는 것과 같아요.",
                    example: nil
                ),
                GuideSection(
                    title: "PR에 포함되는 것",
                    body: "어떤 파일이 어떻게 바뀌었는지(diff), 설명, 리뷰어 지정 등이 포함돼요. 팀원이 코드를 보고 코멘트를 달 수 있어요.",
                    example: nil
                ),
                GuideSection(
                    title: "리뷰와 승인",
                    body: "팀원이 PR을 보고 \"좋아요(Approve)\" 또는 \"수정 필요(Request Changes)\"를 남겨요. 승인되면 머지할 수 있어요.",
                    example: nil
                ),
            ]
        case .merge:
            [
                GuideSection(
                    title: "쉽게 말하면",
                    body: "브랜치에서 작업한 내용을 원본(main)에 합치는 것이에요.",
                    example: nil
                ),
                GuideSection(
                    title: "충돌(Conflict)",
                    body: "두 사람이 같은 파일의 같은 부분을 다르게 수정하면 충돌이 발생해요. 이때는 어느 쪽을 사용할지 직접 선택해야 해요.",
                    example: "피그마에서 두 사람이 같은 프레임을 동시에 다르게 수정하면 생기는 문제와 비슷해요."
                ),
            ]
        case .gitStatus:
            [
                GuideSection(
                    title: "ClaudeWork에서의 Git 상태",
                    body: "앱 하단에 현재 브랜치 이름과 변경사항 수가 표시돼요. 초록색이면 안전, 노란색이면 저장하지 않은 변경이 있다는 뜻이에요.",
                    example: nil
                ),
                GuideSection(
                    title: "상태 종류",
                    body: "Modified(수정됨): 파일이 바뀌었지만 아직 커밋 안 됨\nStaged(준비됨): 커밋할 준비가 된 파일\nUntracked(새 파일): Git이 아직 추적하지 않는 새 파일",
                    example: nil
                ),
            ]
        }
    }
}

struct GuideSection {
    let title: String?
    let body: String
    let example: String?
}

#Preview {
    GitGuideView()
        .frame(width: 700, height: 500)
}
