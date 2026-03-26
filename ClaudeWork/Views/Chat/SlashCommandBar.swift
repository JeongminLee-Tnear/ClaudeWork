import SwiftUI

// MARK: - Slash Command Data

struct SlashCommand: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let category: String
    let icon: String
    let detailDescription: String?

    var command: String { "/\(name)" }

    init(name: String, description: String, category: String, icon: String, detailDescription: String? = nil) {
        self.name = name
        self.description = description
        self.category = category
        self.icon = icon
        self.detailDescription = detailDescription
    }
}

enum SlashCommandRegistry {
    static let commands: [SlashCommand] = [
        // 기획
        SlashCommand(
            name: "office-hours",
            description: "브레인스토밍, 아이디어 논의",
            category: "기획",
            icon: "lightbulb",
            detailDescription: """
            YC 오피스 아워 — 모든 프로젝트의 시작점

            코드를 작성하기 전에 YC 스타일 파트너와 함께 실제로 무엇을 만들고 있는지 고민합니다.

            **두 가지 모드:**
            • **스타트업 모드** — 창업자/사내 기업가용. 수요 현실, 현상 유지, 절박한 구체성, 가장 좁은 쐐기, 관찰과 놀라움, 미래 적합성에 대한 6가지 핵심 질문을 던집니다.
            • **빌더 모드** — 해커톤, 사이드 프로젝트, 오픈소스, 학습용. 아이디어의 가장 멋진 버전을 함께 찾아줍니다.

            **핵심 과정:**
            1. 리프레이밍 — 기능 요청이 아닌 실제 고통을 듣고 제품을 재정의
            2. 전제 검증 — "이게 맞나요?"가 아닌 실제 검증 가능한 주장 제시
            3. 구현 대안 — 2~3가지 구체적 접근법과 노력 추정치 제공

            양쪽 모드 모두 `~/.gstack/projects/`에 디자인 문서를 저장하며, 이 문서는 `/plan-ceo-review`와 `/plan-eng-review`에 직접 연결됩니다.
            """
        ),
        SlashCommand(
            name: "autoplan",
            description: "자동 리뷰 파이프라인 (CEO + Design + Eng)",
            category: "기획",
            icon: "arrow.triangle.2.circlepath",
            detailDescription: """
            자동 리뷰 파이프라인

            CEO, 디자인, 엔지니어링 리뷰 스킬을 순차적으로 실행하고, 6가지 의사결정 원칙에 따라 자동으로 결정합니다.

            취향이 필요한 결정(근접한 접근법, 경계선상의 범위, 의견 불일치)은 최종 승인 게이트에서 한꺼번에 표시합니다. 한 번의 명령으로 완전히 리뷰된 플랜을 만들어냅니다.
            """
        ),

        // 리뷰
        SlashCommand(
            name: "plan-ceo-review",
            description: "CEO/창업자 관점 전략 리뷰",
            category: "리뷰",
            icon: "crown",
            detailDescription: """
            CEO/창업자 모드 — "이 제품은 실제로 무엇을 위한 것인가?"

            요청을 문자 그대로 구현하는 것이 아니라, 사용자 관점에서 문제를 재사고하여 필연적이고, 즐겁고, 약간 마법 같은 버전을 찾습니다.

            **예시:** "판매자가 사진을 업로드하게 해주세요" → 단순 파일 선택기가 아니라 "실제로 팔리는 리스팅을 만드는 기능"으로 재정의. 사진에서 제품 식별, SKU 추론, 제목/설명 자동 작성, 최적 대표 이미지 제안 등.

            **네 가지 모드:**
            • **범위 확장** — 야심찬 버전 제안. 각 확장을 개별적으로 선택
            • **선택적 확장** — 현재 범위 유지하면서 기회 탐색
            • **범위 유지** — 기존 플랜에 최대 엄격함 적용
            • **범위 축소** — 최소 실행 가능 버전 도출

            비전과 결정은 `~/.gstack/projects/`에 영구 저장됩니다.
            """
        ),
        SlashCommand(
            name: "plan-eng-review",
            description: "엔지니어링 아키텍처 리뷰",
            category: "리뷰",
            icon: "wrench.and.screwdriver",
            detailDescription: """
            엔지니어링 매니저 모드 — 아이디어를 구축 가능하게 만들기

            제품 방향이 정해진 후, 기술적 골격을 세우는 단계입니다.

            **다루는 영역:**
            • 아키텍처 및 시스템 경계
            • 데이터 흐름 및 상태 전환
            • 실패 모드 및 엣지 케이스
            • 신뢰 경계 및 테스트 커버리지

            **다이어그램 활용:** 시퀀스, 상태, 컴포넌트, 데이터 흐름, 테스트 매트릭스 다이어그램을 강제하여 숨겨진 가정을 드러냅니다.

            **리뷰 준비 대시보드:** 각 리뷰(CEO, Eng, Design)의 결과를 로깅하고 상태를 표시합니다. Eng Review만 필수 게이트입니다.

            **Plan-to-QA 연동:** 테스트 리뷰 섹션 완료 시 테스트 플랜을 자동 저장하여 `/qa` 실행 시 자동 연동됩니다.
            """
        ),
        SlashCommand(
            name: "plan-design-review",
            description: "디자인 플랜 리뷰",
            category: "리뷰",
            icon: "paintbrush",
            detailDescription: """
            시니어 디자이너의 플랜 리뷰 — 코드 작성 전 디자인 검증

            대부분의 플랜은 백엔드만 설명하고 사용자가 실제로 보는 것은 명시하지 않습니다. 빈 상태, 에러 상태, 로딩 상태, 모바일 레이아웃 등이 "구현하면서 결정"으로 미뤄지곤 합니다.

            **7단계 패스:**
            1. 정보 아키텍처
            2. 인터랙션 상태 커버리지
            3. 사용자 여정
            4. AI 슬롭 위험도
            5. 디자인 시스템 정합성
            6. 반응형/접근성
            7. 미해결 디자인 결정

            각 차원을 0-10으로 평가하고, 10점이 어떤 모습인지 설명한 후, 플랜을 수정합니다. 재실행 시 8점 이상 섹션은 빠르게 통과합니다.
            """
        ),
        SlashCommand(
            name: "design-consultation",
            description: "디자인 시스템/브랜드 컨설팅",
            category: "리뷰",
            icon: "paintpalette",
            detailDescription: """
            디자인 파트너 모드 — 처음부터 비주얼 아이덴티티 구축

            디자인 시스템, 폰트, 색상 팔레트 없이 제로에서 시작할 때 사용합니다.

            **제공 내용:**
            • 제품과 사용자에 대한 대화를 통해 커뮤니케이션 방향 결정
            • 완전한 디자인 시스템 제안: 미적 방향, 타이포그래피(3+폰트), 색상 팔레트, 간격 스케일, 레이아웃, 모션 전략
            • 안전한 선택과 창의적 리스크를 구분하여 제안

            **경쟁 리서치:** 같은 분야의 실제 사이트를 스크린샷으로 분석하여 트렌드 파악 후 차별화 포인트 결정.

            **실시간 프리뷰:** HTML 프리뷰 페이지 생성 — 대시보드, 마케팅 사이트 등 실제 제품처럼 렌더링. 라이트/다크 모드 지원.

            최종적으로 `DESIGN.md`를 작성하고 `CLAUDE.md`를 업데이트하여 모든 후속 세션이 디자인 시스템을 준수합니다.
            """
        ),

        // 코드
        SlashCommand(
            name: "review",
            description: "PR 코드 리뷰",
            category: "코드",
            icon: "eye",
            detailDescription: """
            편집증적 스태프 엔지니어 모드 — "아직 뭐가 깨질 수 있는가?"

            테스트 통과가 브랜치의 안전을 의미하지는 않습니다. CI를 통과하지만 프로덕션에서 터지는 버그 클래스를 찾습니다.

            **검사 항목:**
            • N+1 쿼리, 오래된 읽기, 레이스 컨디션
            • 잘못된 신뢰 경계, 누락된 인덱스
            • 이스케이핑 버그, 깨진 불변성
            • 잘못된 재시도 로직
            • 실제 실패 모드를 놓치는 테스트
            • 새로 추가된 상태/타입의 누락된 핸들러 추적

            **자동 수정:** 명백한 기계적 수정(데드 코드, 오래된 주석, N+1)은 자동 적용. 모호한 이슈(보안, 레이스 컨디션)는 판단을 요청합니다.

            **완전성 갭:** 80% 솔루션이고 100% 솔루션이 30분 이내 가능할 때 알려줍니다.
            """
        ),
        SlashCommand(
            name: "codex",
            description: "OpenAI Codex 세컨드 오피니언",
            category: "코드",
            icon: "brain",
            detailDescription: """
            세컨드 오피니언 모드 — 다른 AI의 관점

            Claude의 `/review`와는 완전히 다른 AI(OpenAI Codex CLI)로 같은 diff를 리뷰합니다. 다른 학습 데이터, 다른 맹점, 다른 강점.

            **세 가지 모드:**
            • **리뷰** — diff에 대해 독립적 리뷰 실행. P1~P3 심각도 분류, PASS/FAIL 판정
            • **챌린지** — 적대적 모드. 엣지 케이스, 레이스 컨디션, 보안 홀, 부하 시 실패할 가정을 찾음
            • **상담** — 세션 연속성을 가진 자유 대화. 후속 질문도 컨텍스트 유지

            **교차 모델 분석:** `/review`(Claude)와 `/codex`(OpenAI) 모두 실행 후 겹치는 발견(높은 신뢰도), 각각의 고유 발견을 비교합니다. "두 의사, 같은 환자" 접근법.
            """
        ),
        SlashCommand(
            name: "qa",
            description: "QA 테스트 + 버그 수정",
            category: "코드",
            icon: "ladybug",
            detailDescription: """
            QA 리드 모드 — 체계적 테스트와 자동 수정

            기능 브랜치에서 코딩을 마치고 모든 것이 잘 동작하는지 확인할 때 사용합니다. git diff를 읽고, 변경이 영향을 주는 페이지를 식별하여 테스트합니다.

            **네 가지 모드:**
            • **Diff 인식** — 피처 브랜치에서 자동. `git diff main`을 읽고 영향받는 페이지 테스트
            • **전체** — 앱 전체 탐색. 5-15분. 5-10개 이슈 문서화
            • **빠른** (`--quick`) — 30초 스모크 테스트. 홈페이지 + 상위 5개 네비게이션
            • **회귀** (`--regression`) — 전체 모드 실행 후 이전 베이스라인과 비교

            **자동 회귀 테스트:** 버그 수정 및 검증 시 해당 시나리오를 잡는 회귀 테스트 자동 생성.

            **인증 페이지 테스트:** `/setup-browser-cookies`로 실제 브라우저 세션을 먼저 임포트하세요.
            """
        ),
        SlashCommand(
            name: "qa-only",
            description: "QA 테스트 (리포트만, 수정 없음)",
            category: "코드",
            icon: "doc.text.magnifyingglass",
            detailDescription: """
            QA 리포터 모드 — 리포트만, 코드 수정 없음

            `/qa`와 동일한 방법론이지만 버그를 리포트만 합니다. 코드 변경 없이 순수한 버그 리포트가 필요할 때 사용합니다.

            헬스 스코어, 스크린샷, 재현 단계를 포함한 구조화된 리포트를 생성합니다.
            """
        ),
        SlashCommand(
            name: "design-review",
            description: "비주얼 디자인 QA",
            category: "코드",
            icon: "rectangle.and.pencil.and.ellipsis",
            detailDescription: """
            코딩하는 디자이너 모드 — 라이브 사이트 비주얼 감사 + 수정

            `/plan-design-review`가 구현 전 플랜을 리뷰한다면, `/design-review`는 구현 후 라이브 사이트를 감사하고 수정합니다.

            **80항목 비주얼 감사 후 수정 루프:**
            1. 디자인 문제 발견
            2. 소스 파일 위치 확인
            3. 최소한의 CSS/스타일링 변경
            4. `style(design): FINDING-NNN`으로 커밋
            5. 재방문하여 검증, 수정 전/후 스크린샷 촬영

            **자기 조절:** CSS 전용 변경은 안전하므로 자유롭게 진행, JSX/TSX 변경은 위험 예산에 포함. 최대 30건 수정, 위험 점수 20% 초과 시 중단.

            **AI 슬롭 점수:** 그라디언트 히어로, 3열 그리드, 균일 라운딩 같은 AI가 만든 듯한 패턴을 감지하고 제거합니다.
            """
        ),
        SlashCommand(
            name: "investigate",
            description: "체계적 디버깅, 근본 원인 분석",
            category: "코드",
            icon: "magnifyingglass",
            detailDescription: """
            체계적 디버거 — 근본 원인 없이 수정 없음

            뭔가 고장났는데 원인을 모를 때 사용합니다.

            **철칙:** 근본 원인 조사 없이 수정 금지.

            추측하고 패치하는 대신, 데이터 흐름을 추적하고 알려진 버그 패턴과 매칭하며 가설을 하나씩 테스트합니다. 3번 수정 시도가 실패하면 아키텍처 자체를 의심합니다. "한 번만 더 시도해보자" 악순환을 방지합니다.

            자동으로 `/freeze`를 활성화하여 디버깅 중인 모듈로 편집을 제한합니다.
            """
        ),
        SlashCommand(name: "simplify", description: "변경 코드 품질/효율 리뷰 및 수정", category: "코드", icon: "scissors"),
        SlashCommand(
            name: "benchmark",
            description: "성능 벤치마크 (페이지 로드, Web Vitals)",
            category: "코드",
            icon: "gauge.with.needle",
            detailDescription: """
            성능 회귀 탐지

            브라우즈 데몬을 사용하여 페이지 로드 시간, Core Web Vitals, 리소스 크기의 베이스라인을 설정합니다. 모든 PR에서 변경 전/후를 비교하고, 시간에 따른 성능 추세를 추적합니다.
            """
        ),

        // 배포
        SlashCommand(
            name: "ship",
            description: "PR 생성, 버전 범프, CHANGELOG 업데이트",
            category: "배포",
            icon: "shippingbox",
            detailDescription: """
            릴리즈 머신 모드 — 최종 마일

            빌드할 것을 결정하고, 기술 플랜을 확정하고, 리뷰를 마친 후의 실행 단계입니다.

            **실행 내용:** main과 동기화 → 테스트 실행 → 브랜치 상태 확인 → 변경 로그/버전 업데이트 → 푸시 → PR 생성/업데이트

            **테스트 부트스트랩:** 테스트 프레임워크가 없으면 런타임 감지 → 최적 프레임워크 설치 → 3-5개 실제 테스트 작성 → CI/CD 설정 → TESTING.md 생성

            **커버리지 감사:** 매 실행마다 diff에서 코드 경로 맵을 구축하고 해당 테스트를 검색. 갭에 대해 테스트 자동 생성. PR 본문에 커버리지 표시: `Tests: 42 → 47 (+5 new)`

            **리뷰 게이트:** PR 생성 전 리뷰 준비 대시보드를 확인합니다.
            """
        ),
        SlashCommand(name: "deploy", description: "iOS 앱 배포 (dev/qa/prod)", category: "배포", icon: "iphone.and.arrow.forward"),
        SlashCommand(
            name: "land-and-deploy",
            description: "PR 머지 + 배포 + 프로덕션 검증",
            category: "배포",
            icon: "airplane.departure",
            detailDescription: """
            랜딩 & 배포 워크플로우

            PR을 머지하고, CI와 배포를 기다리며, 카나리 체크를 통해 프로덕션 상태를 검증합니다. `/ship`이 PR을 생성한 후 이어받는 역할입니다.
            """
        ),
        SlashCommand(
            name: "setup-deploy",
            description: "배포 설정 구성",
            category: "배포",
            icon: "gearshape",
            detailDescription: """
            배포 설정 구성

            `/land-and-deploy`를 위한 배포 설정을 구성합니다. 배포 플랫폼(Fly.io, Render, Vercel, Netlify, Heroku, GitHub Actions 등), 프로덕션 URL, 헬스 체크 엔드포인트, 배포 상태 명령어를 자동 감지하고 CLAUDE.md에 설정을 기록합니다.
            """
        ),
        SlashCommand(
            name: "canary",
            description: "배포 후 카나리 모니터링",
            category: "배포",
            icon: "bird",
            detailDescription: """
            카나리 모니터링

            배포 후 라이브 앱을 감시합니다. 콘솔 에러, 성능 회귀, 페이지 실패를 헤드리스 브라우저로 모니터링합니다. 주기적 스크린샷 촬영, 배포 전 베이스라인과 비교, 이상 징후 발견 시 알림.
            """
        ),
        SlashCommand(
            name: "document-release",
            description: "릴리즈 후 문서 업데이트",
            category: "배포",
            icon: "doc.badge.plus",
            detailDescription: """
            테크니컬 라이터 모드

            `/ship`이 PR을 생성한 후, 머지 전에 모든 문서 파일을 읽고 diff와 교차 참조합니다.

            **자동 업데이트 항목:**
            • 파일 경로, 명령어 목록, 프로젝트 구조 트리
            • CHANGELOG 문체 다듬기 (기존 항목 덮어쓰기 없음)
            • 완료된 TODO 정리
            • 문서 간 일관성 체크

            위험하거나 주관적인 변경은 질문으로 표시하고, 나머지는 자동 처리합니다.
            """
        ),
        SlashCommand(name: "app-store-changelog", description: "App Store 릴리즈 노트 생성", category: "배포", icon: "list.bullet.rectangle"),

        // 브라우저
        SlashCommand(
            name: "browse",
            description: "헤드리스 브라우저로 웹 브라우징",
            category: "브라우저",
            icon: "globe",
            detailDescription: """
            QA 엔지니어 모드 — 에이전트에게 눈을 부여

            컴파일된 바이너리가 지속적 Chromium 데몬과 통신합니다. 첫 호출은 ~3초, 이후 호출은 ~100-200ms. 브라우저는 명령 사이에 유지되어 쿠키, 탭, localStorage가 이어집니다.

            **주요 기능:**
            • 실제 Chromium 브라우저, 실제 클릭, 실제 스크린샷
            • 페이지 이동, 요소 상호작용, 상태 확인
            • 폼 작성, 파일 업로드, 다이얼로그 처리
            • 반응형 레이아웃 테스트
            • 변경 전/후 diff 비교

            **브라우저 핸드오프:** CAPTCHA나 MFA에 막히면 사용자에게 보이는 Chrome을 열어 직접 처리 가능. 모든 상태(쿠키, localStorage, 탭) 유지.

            30분 유휴 시 자동 종료됩니다.
            """
        ),
        SlashCommand(name: "gstack", description: "헤드리스 브라우저 QA/도그푸딩", category: "브라우저", icon: "network"),
        SlashCommand(
            name: "setup-browser-cookies",
            description: "브라우저 쿠키 임포트",
            category: "브라우저",
            icon: "key",
            detailDescription: """
            세션 매니저 모드

            `/qa`나 `/browse`가 인증된 페이지를 테스트하기 전에 쿠키가 필요합니다. 매번 헤드리스 브라우저로 수동 로그인하는 대신, 실제 브라우저에서 세션을 직접 가져옵니다.

            **지원 브라우저:** Chrome, Arc, Brave, Edge 등 Chromium 기반 브라우저를 자동 감지합니다.

            **동작 방식:**
            1. macOS 키체인을 통해 쿠키 복호화
            2. 인터랙티브 피커 UI에서 임포트할 도메인 선택
            3. 쿠키 값은 절대 표시되지 않음

            특정 도메인만 바로 임포트도 가능: `/setup-browser-cookies github.com`
            """
        ),

        // 안전
        SlashCommand(
            name: "careful",
            description: "파괴적 명령 경고 모드",
            category: "안전",
            icon: "exclamationmark.triangle",
            detailDescription: """
            안전 가드레일 — 파괴적 명령 경고

            프로덕션 근처에서 작업하거나 안전망이 필요할 때 사용합니다.

            **감지하는 위험 패턴:**
            • `rm -rf` / `rm -r` — 재귀 삭제
            • `DROP TABLE` / `DROP DATABASE` / `TRUNCATE` — 데이터 손실
            • `git push --force` — 히스토리 재작성
            • `git reset --hard` — 커밋 폐기
            • `git checkout .` / `git restore .` — 미커밋 작업 폐기
            • `kubectl delete` — 프로덕션 리소스 삭제
            • `docker rm -f` / `docker system prune` — 컨테이너/이미지 손실

            일반적인 빌드 아티팩트 정리(node_modules, dist, .next 등)는 화이트리스트 처리되어 오탐 없음. 모든 경고는 오버라이드 가능합니다.
            """
        ),
        SlashCommand(
            name: "freeze",
            description: "특정 디렉토리만 편집 허용",
            category: "안전",
            icon: "lock",
            detailDescription: """
            편집 잠금 — 디렉토리 범위 제한

            빌링 버그를 디버깅할 때 Claude가 실수로 `src/auth/`를 "수정"하는 것을 방지합니다.

            **사용법:** `/freeze src/billing` → `src/billing/` 외부의 모든 Edit/Write 작업 차단.

            `/investigate`는 디버깅 중인 모듈을 자동 감지하여 이 기능을 자동 활성화합니다.

            참고: Edit/Write 도구만 차단합니다. Bash의 `sed` 같은 명령은 경계 외부 파일도 수정 가능 — 사고 방지용이지 보안 샌드박스가 아닙니다.
            """
        ),
        SlashCommand(
            name: "unfreeze",
            description: "편집 제한 해제",
            category: "안전",
            icon: "lock.open",
            detailDescription: """
            잠금 해제

            `/freeze`로 설정한 경계를 제거하여 모든 디렉토리 편집을 다시 허용합니다. 훅은 세션 동안 등록된 상태로 유지되며 모든 것을 허용합니다. `/freeze`를 다시 실행하면 새 경계를 설정할 수 있습니다.
            """
        ),
        SlashCommand(
            name: "guard",
            description: "최대 안전 모드 (careful + freeze)",
            category: "안전",
            icon: "shield",
            detailDescription: """
            최대 안전 모드

            `/careful`(파괴적 명령 경고)과 `/freeze`(디렉토리 범위 편집 제한)를 하나로 결합합니다. 프로덕션을 다루거나 라이브 시스템을 디버깅할 때 사용합니다.
            """
        ),
        SlashCommand(
            name: "cso",
            description: "보안 감사 (CSO 모드)",
            category: "안전",
            icon: "shield.checkered",
            detailDescription: """
            최고 보안 책임자(CSO) 모드

            OWASP Top 10 + STRIDE 위협 모델링 보안 감사를 수행합니다.

            **검사 항목:**
            • 인젝션 취약점 (SQL, 커맨드, XSS)
            • 인증/세션 관리 결함
            • 민감 데이터 노출
            • XML 외부 엔터티 (XXE)
            • 접근 제어 취약점
            • 보안 설정 오류
            • 안전하지 않은 역직렬화
            • 알려진 취약 컴포넌트
            • 불충분한 로깅

            각 발견 사항에 심각도, 증거, 권장 수정 사항을 포함합니다.
            """
        ),

        // 유틸리티
        SlashCommand(
            name: "retro",
            description: "주간 엔지니어링 회고",
            category: "유틸리티",
            icon: "clock.arrow.circlepath",
            detailDescription: """
            엔지니어링 매니저 모드 — 주간 회고

            주말에 실제로 무엇이 일어났는지 데이터로 파악합니다.

            **분석 내용:**
            • 커밋 히스토리, 작업 패턴, 배포 속도
            • 팀원별 기여도 (커밋, LOC, 테스트 비율, PR 크기)
            • 코딩 세션 감지 (커밋 타임스탬프 기반)
            • 핫스팟 파일 식별
            • 배포 연속 기록
            • 주간 최대 성과

            **테스트 건강도:** 전체 테스트 파일, 추가된 테스트, 회귀 테스트 커밋, 추세 변화 추적. 테스트 비율 20% 미만 시 경고.

            각 팀원에 대해 구체적 칭찬과 성장 기회를 제공합니다. `.context/retros/`에 JSON 스냅샷을 저장하여 다음 실행 시 추세를 보여줍니다.
            """
        ),
        SlashCommand(name: "loop", description: "반복 실행 (예: /loop 5m /qa)", category: "유틸리티", icon: "repeat"),
        SlashCommand(name: "schedule", description: "크론 스케줄 원격 에이전트 설정", category: "유틸리티", icon: "calendar.badge.clock"),
        SlashCommand(
            name: "gstack-upgrade",
            description: "gstack 최신 버전 업그레이드",
            category: "유틸리티",
            icon: "arrow.up.circle",
            detailDescription: """
            자동 업그레이드

            설치 유형(글로벌 `~/.claude/skills/gstack` vs 프로젝트별 `.claude/skills/gstack`)을 자동 감지하고, 업그레이드를 실행하며, 듀얼 설치 시 양쪽을 동기화하고, 변경 사항을 보여줍니다.

            `~/.gstack/config.yaml`에서 `auto_upgrade: true`를 설정하면 새 버전이 있을 때 세션 시작 시 자동으로 업그레이드합니다.
            """
        ),
    ]

    static func filtered(by query: String) -> [SlashCommand] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        if q.isEmpty || q == "/" { return commands }
        let search = q.hasPrefix("/") ? String(q.dropFirst()) : q
        return commands.filter {
            $0.name.lowercased().contains(search) ||
            $0.description.lowercased().contains(search)
        }
    }
}

// MARK: - Slash Command Popup

struct SlashCommandPopup: View {
    let query: String
    let onSelect: (SlashCommand) -> Void
    @Binding var selectedIndex: Int
    @State private var detailCommand: SlashCommand?

    private var filtered: [SlashCommand] {
        SlashCommandRegistry.filtered(by: query)
    }

    func showDetailForSelected() {
        let cmds = filtered
        guard selectedIndex >= 0, selectedIndex < cmds.count else { return }
        let cmd = cmds[selectedIndex]
        if cmd.detailDescription != nil {
            detailCommand = cmd
        }
    }

    var body: some View {
        if filtered.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // 헤더
                HStack {
                    Image(systemName: "command")
                        .font(.system(size: 10))
                        .foregroundStyle(ClaudeTheme.textTertiary)
                    Text("슬래시 명령어")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ClaudeTheme.textTertiary)
                    Spacer()
                    Text("\(filtered.count)개")
                        .font(.system(size: 10))
                        .foregroundStyle(ClaudeTheme.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                Divider()
                    .foregroundStyle(ClaudeTheme.borderSubtle)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { index, cmd in
                                commandRowButton(cmd, isSelected: index == selectedIndex)
                                    .id(index)
                            }
                        }
                    }
                    .onChange(of: selectedIndex) { _, newValue in
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
            .frame(maxHeight: 320)
            .background(ClaudeTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusMedium)
                    .strokeBorder(ClaudeTheme.border, lineWidth: 1)
            )
            .shadow(color: ClaudeTheme.shadowColor, radius: 12, y: -4)
            .sheet(item: $detailCommand) { cmd in
                CommandDetailSheet(command: cmd)
            }
        }
    }

    @ViewBuilder
    private func commandRowButton(_ cmd: SlashCommand, isSelected: Bool) -> some View {
        HStack(spacing: 0) {
            // 클릭하면 명령어 실행되는 영역
            Button {
                onSelect(cmd)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: cmd.icon)
                        .font(.system(size: 13))
                        .foregroundStyle(isSelected ? ClaudeTheme.accent : ClaudeTheme.textSecondary)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(cmd.command)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(isSelected ? ClaudeTheme.accent : ClaudeTheme.textPrimary)

                        Text(cmd.description)
                            .font(.system(size: 11))
                            .foregroundStyle(ClaudeTheme.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // 상세 정보 버튼 (별도 영역, 명령어 실행 안 됨)
            if cmd.detailDescription != nil {
                Button {
                    detailCommand = cmd
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(ClaudeTheme.textTertiary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }

            Text(cmd.category)
                .font(.system(size: 10))
                .foregroundStyle(ClaudeTheme.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(ClaudeTheme.surfaceSecondary, in: Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? ClaudeTheme.accentSubtle : Color.clear)
    }

    var filteredCount: Int { filtered.count }

    func command(at index: Int) -> SlashCommand? {
        guard index >= 0 && index < filtered.count else { return nil }
        return filtered[index]
    }
}

// MARK: - Command Detail Sheet

struct CommandDetailSheet: View {
    let command: SlashCommand
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 헤더
            HStack {
                Image(systemName: command.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(ClaudeTheme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(command.command)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(ClaudeTheme.textPrimary)

                    Text(command.description)
                        .font(.system(size: 13))
                        .foregroundStyle(ClaudeTheme.textSecondary)
                }

                Spacer()

                Text(command.category)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ClaudeTheme.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ClaudeTheme.surfaceSecondary, in: Capsule())
            }
            .padding(20)

            ClaudeThemeDivider()

            // 본문
            ScrollView {
                if let detail = command.detailDescription {
                    Text(LocalizedStringKey(detail))
                        .font(.system(size: 13))
                        .foregroundStyle(ClaudeTheme.textPrimary)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                }
            }

            ClaudeThemeDivider()

            // 닫기
            HStack {
                Spacer()
                Button("닫기") { dismiss() }
                    .buttonStyle(ClaudeSecondaryButtonStyle())
            }
            .padding(16)
        }
        .frame(width: 520, height: 480)
        .background(ClaudeTheme.background)
    }
}

// MARK: - SlashCommand + Identifiable for sheet

extension SlashCommand: Hashable {
    static func == (lhs: SlashCommand, rhs: SlashCommand) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Command Menu Button

struct CommandMenuButton: View {
    let messages: [ChatMessage]
    @Environment(AppState.self) private var appState
    @State private var isCopied = false
    @State private var showUsagePopover = false

    var body: some View {
        Menu {
            Button {
                copyConversation()
            } label: {
                Label(isCopied ? "복사됨" : "대화 내용 복사", systemImage: isCopied ? "checkmark" : "doc.on.doc")
            }
            .disabled(messages.isEmpty)

            Button {
                showUsagePopover = true
            } label: {
                Label("사용량", systemImage: "chart.bar")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 14))
                .foregroundStyle(ClaudeTheme.textSecondary)
        }
        .buttonStyle(.borderless)
        .menuIndicator(.hidden)
        .help("명령어")
        .popover(isPresented: $showUsagePopover, arrowEdge: .top) {
            UsagePopoverView()
                .environment(appState)
        }
    }

    private func copyConversation() {
        let text = messages.map { msg in
            let role = msg.role == .user ? "나" : "Claude"
            return "[\(role)] \(msg.content)"
        }.joined(separator: "\n\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        isCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isCopied = false
        }
    }
}

// MARK: - Usage Popover

struct UsagePopoverView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("세션 사용량")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ClaudeTheme.textPrimary)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                usageRow(icon: "dollarsign.circle", label: "비용", value: formatCost(appState.sessionCostUsd))
                usageRow(icon: "arrow.down.circle", label: "입력 토큰", value: formatTokens(appState.sessionInputTokens))
                usageRow(icon: "arrow.up.circle", label: "출력 토큰", value: formatTokens(appState.sessionOutputTokens))
                usageRow(icon: "square.stack", label: "캐시 생성", value: formatTokens(appState.sessionCacheCreationTokens))
                usageRow(icon: "square.stack.fill", label: "캐시 읽기", value: formatTokens(appState.sessionCacheReadTokens))
                usageRow(icon: "clock", label: "소요 시간", value: formatDuration(appState.sessionDurationMs))
                usageRow(icon: "arrow.triangle.2.circlepath", label: "턴 수", value: "\(appState.sessionTurns)")
            }
        }
        .padding(16)
        .frame(width: 240)
    }

    @ViewBuilder
    private func usageRow(icon: String, label: String, value: String) -> some View {
        GridRow {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(ClaudeTheme.textTertiary)
                    .frame(width: 14)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(ClaudeTheme.textSecondary)
            }
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(ClaudeTheme.textPrimary)
        }
    }

    private func formatCost(_ cost: Double) -> String {
        if cost == 0 { return "—" }
        return String(format: "$%.4f", cost)
    }

    private func formatTokens(_ tokens: Int) -> String {
        if tokens == 0 { return "—" }
        if tokens >= 1_000_000 {
            return String(format: "%.1fm", Double(tokens) / 1_000_000)
        } else if tokens >= 1_000 {
            return String(format: "%.1fk", Double(tokens) / 1_000)
        }
        return "\(tokens)"
    }

    private func formatDuration(_ ms: Double) -> String {
        if ms == 0 { return "—" }
        let seconds = Int(ms / 1_000)
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        let secs = seconds % 60
        return "\(minutes)m \(secs)s"
    }
}

#Preview {
    CommandMenuButton(messages: [
        ChatMessage(role: .user, content: "안녕"),
        ChatMessage(role: .assistant, content: "안녕하세요!"),
    ])
    .environment(AppState())
    .padding()
}
