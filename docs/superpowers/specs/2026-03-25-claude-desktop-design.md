# Claude Desktop — 설계 문서

> macOS 26 네이티브 앱. `claude -p --output-format stream-json` 위에 SwiftUI UI를 씌워 비개발자도 Claude Code를 사용할 수 있게 한다.

## 결정 사항

| 항목 | 결정 | 이유 |
|------|------|------|
| 빌드 시스템 | Xcode 프로젝트 유지 | 이미 세팅 완료, FSRG 자동 파일 인식 |
| App Sandbox | 끔 | Process spawn, SSH, NWListener 필요 |
| 상태 관리 | `@Observable` + `@MainActor` | Swift 6, Combine 불필요 |
| 스트리밍 | `AsyncStream<StreamEvent>` | 구조화 동시성, 취소 지원 |
| Tool 승인 | PreToolUse HTTP hook (NWListener) | clui-cc 검증 완료 |
| 저장 | JSON (Application Support) | 의존성 없음 |

## 데모 성공 기준

터미널을 한 번도 열지 않은 팀원이, GitHub 로그인 후 레포를 선택하고 5분 안에 첫 번째 Claude Code 응답을 받는다.

## P0 기능

1. 온보딩 — Claude Code 설치 감지, 안내
2. GitHub 연동 — OAuth → SSH 자동 설정 → 레포 목록
3. 프로젝트 관리 — GitHub 레포 선택 / 로컬 폴더 드래그&드롭
4. 채팅 UI — 실시간 스트리밍 응답
5. Tool 승인 모달 — 위험도별 승인 UI
6. 히스토리 — 대화 저장 + `--resume`으로 세션 재개

---

## 프로젝트 구조

```
ClaudeWork/
├── App/
│   ├── ClaudeWorkApp.swift
│   └── AppState.swift
├── Models/
│   ├── StreamEvent.swift
│   ├── ChatMessage.swift
│   ├── Project.swift
│   ├── PermissionRequest.swift
│   └── JSONValue.swift
├── Services/
│   ├── ClaudeService.swift
│   ├── GitHubService.swift
│   ├── PermissionServer.swift
│   └── PersistenceService.swift
├── Views/
│   ├── MainView.swift
│   ├── Sidebar/
│   │   ├── ProjectListView.swift
│   │   └── HistoryListView.swift
│   ├── Chat/
│   │   ├── ChatView.swift
│   │   ├── MessageBubble.swift
│   │   └── ToolResultView.swift
│   ├── Permission/
│   │   └── PermissionModal.swift
│   └── Onboarding/
│       ├── OnboardingView.swift
│       └── GitHubLoginView.swift
└── Utilities/
    ├── NDJSONParser.swift
    └── SSHKeyManager.swift
```

---

## 데이터 모델

### StreamEvent (NDJSON 파싱)

```swift
enum StreamEvent: Decodable {
    case system(SystemEvent)
    case streamEvent(StreamEventData)
    case assistant(AssistantMessage)
    case user(UserMessage)
    case result(ResultEvent)
    case rateLimitEvent(RateLimitInfo)
    case unknown(String)
}

struct SystemEvent: Decodable {
    let subtype: String        // "init", "hook_started", "hook_response"
    let sessionId: String?
    let tools: [String]?
    let model: String?
    let claudeCodeVersion: String?
}

struct StreamEventData: Decodable {
    let sessionId: String
    let parentToolUseId: String?
    let event: ContentEvent
}

enum ContentEvent: Decodable {
    case messageStart(MessageStartData)
    case contentBlockStart(index: Int, contentBlock: ContentBlock)
    case contentBlockDelta(index: Int, delta: Delta)
    case contentBlockStop(index: Int)
    case messageDelta(stopReason: String?, usage: Usage?)
    case messageStop
}

enum ContentBlock: Decodable {
    case text(String)
    case toolUse(id: String, name: String, input: [String: JSONValue])
    case thinking(String)
}

enum Delta: Decodable {
    case textDelta(String)
    case inputJsonDelta(String)
}
```

### ChatMessage (UI용)

```swift
struct ChatMessage: Identifiable, Codable, Sendable {
    let id: UUID
    let role: Role               // .user, .assistant
    var content: String          // 스트리밍 중 점진적 추가
    var toolCalls: [ToolCall]
    var isStreaming: Bool
    let timestamp: Date
}

enum Role: String, Codable, Sendable {
    case user, assistant
}

struct ToolCall: Identifiable, Codable, Sendable {
    let id: String              // toolu_01...
    let name: String            // Bash, Edit 등
    let input: [String: JSONValue]
    var result: String?
    var isError: Bool
}
```

### JSONValue

```swift
enum JSONValue: Codable, Sendable, CustomStringConvertible {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null
}
```

### Project

```swift
struct Project: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var path: String
    var gitHubRepo: String?      // owner/repo
    var lastSessionId: String?   // --resume 용
}
```

### PermissionRequest

```swift
struct PermissionRequest: Identifiable, Sendable {
    let id: String              // tool_use_id
    let toolName: String
    let toolInput: [String: JSONValue]
    let runToken: String
}

enum PermissionDecision: String, Sendable {
    case allow, deny
}
```

### ChatSession

```swift
struct ChatSession: Identifiable, Codable, Sendable {
    let id: String              // session_id from Claude CLI
    let projectId: UUID
    var title: String           // 첫 번째 사용자 메시지 요약
    var messages: [ChatMessage]
    let createdAt: Date
    var updatedAt: Date
}
```

### GitHubUser / GitHubRepo

```swift
struct GitHubUser: Codable, Sendable {
    let login: String
    let name: String?
    let avatarUrl: String
}

struct GitHubRepo: Identifiable, Codable, Sendable {
    let id: Int
    let fullName: String        // owner/name
    let name: String
    let owner: GitHubRepoOwner
    let isPrivate: Bool
    let htmlUrl: String

    struct GitHubRepoOwner: Codable, Sendable {
        let login: String
    }
}
```

---

## 서비스 레이어

### ClaudeService (actor)

프로세스 생명주기 관리 + NDJSON 스트림 파싱.

```
spawn 명령:
  claude -p
    --output-format stream-json
    --verbose
    --include-partial-messages
    --input-format stream-json
    [--resume <sessionId>]
    [--allowedTools Read,Glob,Grep]

주의: hook 설정은 프로젝트 cwd의 .claude/settings.local.json에 기록한다.
--settings 플래그는 존재하지 않을 수 있으므로, 프로세스 spawn 전에
cwd/.claude/settings.local.json을 생성하고 spawn 후 정리한다.

stdin 입력 (NDJSON):
  {"type":"user","message":{"role":"user","content":[{"type":"text","text":"..."}]}}

stdout → NDJSONParser → AsyncStream<StreamEvent>
```

**API:**
- `send(prompt:cwd:sessionId:) -> AsyncStream<StreamEvent>`
- `cancel()` — SIGINT → 5초 후 SIGKILL

**바이너리 탐색 순서:**
1. `/usr/local/bin/claude`
2. `/opt/homebrew/bin/claude`
3. `~/.npm-global/bin/claude`
4. `zsh -ilc "whence -p claude"`

### PermissionServer (actor)

NWListener 기반 로컬 HTTP 서버. PreToolUse hook 요청 수신.

```
포트: 19836 (충돌 시 자동 증가)
엔드포인트: POST /hook/pre-tool-use/{appSecret}/{runToken}

요청 본문:
{
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": {"command": "npm install"},
  "tool_use_id": "toolu_01..."
}

응답 본문:
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow" | "deny",
    "permissionDecisionReason": "..."
  }
}
```

**동작:**
1. 요청 수신 → `PermissionRequest` 생성 → `AppState.pendingPermissions`에 append
2. `CheckedContinuation`으로 UI 응답 대기
3. 응답 수신 → JSON 응답 반환
4. 타임아웃 5분 → 자동 deny

**자동 승인:** Read, Glob, Grep 등 안전한 도구는 `--allowedTools`로 hook 우회.

**Hook 설정 파일** (`$TMPDIR/claudework-hook-{runToken}.json`):
```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "^(Bash|Edit|Write|MultiEdit|mcp__.*)$",
      "hooks": [{
        "type": "http",
        "url": "http://127.0.0.1:{port}/hook/pre-tool-use/{appSecret}/{runToken}",
        "timeout": 300
      }]
    }]
  }
}
```

### GitHubService (actor)

**OAuth 흐름:**
1. `ASWebAuthenticationSession` — `github.com/login/oauth/authorize?client_id=...&scope=repo,read:org`
2. Callback URL: `claudedesktop://oauth/callback?code=...`
3. POST `github.com/login/oauth/access_token` — code → token 교환 (client_secret 필요)
4. token을 Keychain에 저장

> **client_secret**: 데모용으로 앱 내 상수에 하드코딩. 프로덕션에서는 백엔드 프록시로 이동 필요.

**SSH 자동 설정:**
1. `ssh-keygen -t ed25519 -f ~/.ssh/claudework_ed25519 -N ""`
2. POST `/user/keys` — 공개키 등록 (title: "ClaudeWork")
3. `~/.ssh/config` 확인 → 기존 `Host github.com` 없으면 추가, 있으면 건너뜀:
   ```
   Host github.com
     IdentityFile ~/.ssh/claudework_ed25519
   ```

**레포 목록:**
- GET `/user/repos?per_page=100&sort=updated`
- `permissions.pull == true` 필터링

**Clone:**
- `git clone git@github.com:{owner}/{name}.git {path}`

### PersistenceService (actor)

저장 경로: `~/Library/Application Support/ClaudeWork/`

| 파일 | 내용 |
|------|------|
| `projects.json` | `[Project]` |
| `sessions/{projectId}/{sessionId}.json` | `ChatSession` (메시지 + 메타) |
| `github_user.json` | `GitHubUser` (캐시) |

---

## AppState

```swift
@Observable
final class AppState {
    // 프로젝트
    var projects: [Project] = []
    var selectedProject: Project?

    // 채팅
    var messages: [ChatMessage] = []
    var isStreaming = false
    var inputText = ""

    // 세션
    var sessions: [ChatSession] = []
    var currentSessionId: String?

    // Tool 승인 (큐 — 병렬 tool call 대응)
    var pendingPermissions: [PermissionRequest] = []

    // GitHub
    var isLoggedIn = false
    var gitHubUser: GitHubUser?
    var repos: [GitHubRepo] = []

    // 온보딩
    var claudeInstalled = false
    var onboardingCompleted = false

    // 서비스
    let claude: ClaudeService
    let github: GitHubService
    let permission: PermissionServer
    let persistence: PersistenceService
}
```

---

## 뷰 계층

```
ClaudeWorkApp
└── MainView (NavigationSplitView)
    ├── Sidebar
    │   ├── ProjectListView        # 프로젝트 목록 + 추가 버튼
    │   └── HistoryListView        # 세션 히스토리
    ├── Detail
    │   └── ChatView
    │       ├── ScrollView         # MessageBubble + ToolResultView
    │       └── InputBar           # TextField + 전송
    └── Overlays
        ├── PermissionModal (.sheet)
        ├── OnboardingView
        └── GitHubLoginView
```

### ChatView 데이터 흐름

```
사용자 입력 → AppState.send()
  → ClaudeService.send(prompt, cwd, sessionId)
  → AsyncStream<StreamEvent> 반환

for await event in stream:
  .system(.init)       → sessionId 저장
  .streamEvent(.contentBlockDelta(.textDelta)) → message.content += text
  .streamEvent(.contentBlockStart(.toolUse))   → ToolCall 추가
  .user(toolResult)    → ToolCall.result 업데이트
  .result              → isStreaming = false, 세션 저장
```

### PermissionModal 동작

```
AppState.pendingPermissions.first != nil → .sheet 표시
  → Tool 이름, 입력 내용 표시
  → [Allow] → PermissionServer.respond(id, .allow), removeFirst()
  → [Deny]  → PermissionServer.respond(id, .deny), removeFirst()
```

---

## 에러 처리

| 상황 | 처리 |
|------|------|
| claude 미설치 | 온보딩에서 설치 안내 |
| 프로세스 크래시 | stderr 마지막 20줄 표시 + 재시도 버튼 |
| OAuth 실패 | 얼럿 + 재시도 |
| SSH 키 등록 실패 | 수동 설정 안내 폴백 |
| PermissionServer 포트 충돌 | 19836부터 자동 증가 |
| Hook 타임아웃 (5분) | 자동 deny |
| 네트워크 끊김 | 로컬 폴더 모드로 폴백 |

---

## 온보딩 플로우

```
앱 실행
  → which claude 확인
  → 미설치: "npm install -g @anthropic-ai/claude-code" 안내 + 복사 버튼
  → 설치됨: GitHub 로그인 제안 (건너뛰기 가능)
    → 로그인: SSH 자동 설정 → 레포 목록 로드
    → 건너뛰기: 로컬 폴더 드래그&드롭으로 시작
```

---

## NDJSON 프로토콜 레퍼런스

clui-cc 소스 + 실제 CLI 출력에서 확인된 메시지 타입:

| type | 용도 | 주요 필드 |
|------|------|-----------|
| `system` (init) | 세션 초기화 | session_id, tools, model |
| `system` (hook_started/hook_response) | Hook 생명주기 | hook_name, output |
| `stream_event` | API 스트리밍 | event.type (message_start, content_block_delta 등) |
| `assistant` | 완성된 메시지 | message.content (text, tool_use, thinking) |
| `user` | Tool 결과 | tool_use_id, content, is_error |
| `result` | 최종 결과 | duration_ms, total_cost_usd, session_id |
| `rate_limit_event` | 속도 제한 | rate_limit_info.status |

### 프로세스 spawn 명령

```bash
claude -p \
  --output-format stream-json \
  --verbose \
  --include-partial-messages \
  --input-format stream-json \
  [--resume <session-id>] \
  [--settings <hook-settings-file>] \
  [--allowedTools "Read,Glob,Grep"]
```

### stdin 입력 포맷

```json
{"type":"user","message":{"role":"user","content":[{"type":"text","text":"사용자 메시지"}]}}
```

### 바이너리 탐색 순서

1. `/usr/local/bin/claude`
2. `/opt/homebrew/bin/claude`
3. `~/.npm-global/bin/claude`
4. `zsh -ilc "whence -p claude"` (폴백)
