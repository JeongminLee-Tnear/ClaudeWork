변경사항 제출 — `branch-role` 스킬의 "세션 역할" 설정에 따라 동작합니다.

## 필수 스킬

이 커맨드 실행 시 반드시 `git-workflow` + `branch-role` 스킬을 먼저 로드할 것.

## 사전 체크 (하나라도 실패 시 중단)

1. `branch-role` 스킬의 **"세션 역할"** 확인 (`.claude/role` 파일 읽기, 없으면 `dev`)
2. **브랜치 확인**: 역할에 맞는 브랜치에서만 실행 가능
   - `dev` → `dev/*` 또는 `hotfix/*`
   - `design` → `design/*`
   - `pm` → `pm/*`
   - `po` → `po/*`
   - 실패 시: "⛔ 현재 브랜치가 역할과 맞지 않습니다. /start로 브랜치를 만드세요."
3. **보호 브랜치 차단**: `main`, `qa`에서는 절대 실행 금지
4. **변경사항 존재 확인**: `git status`로 확인
   - 없으면: "변경사항이 없습니다."

## 위험 파일 스캔

### 공통 (모든 역할)
- `.env`, `.env.*` — 환경변수/시크릿
- `*.p12`, `*.mobileprovision`, `*.cer` — 인증서

### design, pm, po 역할 추가 제외
- `Podfile`, `Podfile.lock` — CocoaPods 설정
- `Package.swift`, `Package.resolved` — SPM 설정
- `*.pbxproj`, `*.xcworkspace` — Xcode 프로젝트 설정
- `fastlane/`, `Gemfile*` — 빌드/배포 설정

해당 파일은 자동 제외하고 사용자에게 알림.

## 코드 정리

커밋 전 `/simplify`를 실행하여 변경된 코드를 검토하고 정리:
- 중복 코드, 불필요한 복잡도, 개선 가능한 패턴을 자동 탐지 및 수정
- 수정사항이 있으면 사용자에게 diff를 보여주고 확인 후 반영

## 실행 절차

1. 안전한 파일만 `git add`
2. `/simplify` 실행 — 변경된 코드 정리
3. 변경사항 요약을 사용자에게 보여주고 확인 요청
4. `git-workflow` 스킬의 Conventional Commit 규칙에 따라 커밋 메시지 자동 생성

### dev 역할: qa 직접 머지
```bash
git checkout qa
git pull origin qa
git merge {브랜치명}
git push origin qa
```
- hotfix 브랜치인 경우: `main`에 머지

### design, pm, po 역할: PR 생성
```bash
git push -u origin {브랜치명}
gh pr create --base qa --title "{제목}" --body "{본문}"
```

## 출력 포맷

### dev 역할
```
📋 변경사항 요약:
  - {file1}: {변경 설명}

⚠️ 제외된 파일: {있으면 목록}

🔀 qa 브랜치에 머지 완료!
💡 배포가 필요하면 /deploy qa를 실행하세요.
```

### design, pm, po 역할
```
📋 변경사항 요약:
  - {file1}: {변경 설명}

⚠️ 제외된 파일 (빌드 설정): {있으면 목록}

🚀 PR 생성 완료!
🔗 {PR URL}
👉 이 링크를 Slack에 공유하세요.
```
