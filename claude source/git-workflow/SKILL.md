---
name: git-workflow
description: Git workflow guidance for commits, branches, and pull requests
---
# Git Workflow Skill

You are a Git workflow assistant. Help users with commits, branches, and pull requests following best practices.

## Commit Message Guidelines

For commit message generation and validation, use `get_skill_script("git-workflow", "commit_message.py")`.

### 작성 규칙

- 제목과 본문을 빈 행으로 구분한다
- 제목을 50글자 내로 제한
- 제목 첫 글자는 대문자로 작성
- 제목 끝에 마침표 넣지 않기
- 제목은 명령문으로 사용하며 과거형을 사용하지 않는다
- 본문의 각 행은 72글자 내로 제한
- 어떻게 보다는 무엇과 왜를 설명한다

### Format
```
<type>(<scope>): <subject>          -- 헤더 (필수)

<body>                              -- 본문 (선택)

<footer>                            -- 바닥글 (선택)
```

### Types
- **feat**: 새로운 기능에 대한 커밋
- **fix**: 버그 수정에 대한 커밋
- **build**: 빌드 관련 파일 수정에 대한 커밋
- **chore**: 그 외 자잘한 수정에 대한 커밋
- **ci**: CI관련 설정 수정에 대한 커밋
- **docs**: 문서 수정에 대한 커밋
- **style**: 코드 스타일 혹은 포맷 등에 관한 커밋
- **refactor**: 코드 리팩토링에 대한 커밋
- **test**: 테스트 코드 수정에 대한 커밋
- **release**: 배포 관련 수정에 대한 커밋

### Examples
```
feat(auth): Add OAuth2 login support

Implemented OAuth2 authentication flow with Google and GitHub providers.
Added token refresh mechanism and session management.

Closes #123
```

```
fix(api): Handle null response from external service

Added null check before processing response data to prevent
NullPointerException when external service returns empty response.

Fixes #456
```

## 브랜치 전략

### 영구 브랜치

| 브랜치 | 역할 |
|---|---|
| `main` | 마켓 배포된 안정 버전 |
| `qa` | 통합 테스트 / 리뷰 브랜치 |

### 작업 브랜치

| 브랜치명 | 예시 |
|---|---|
| `dev/<기능명>` | `dev/push-notification` |
| `design/<기능명>` | `design/new-onboarding` |
| `pm/<기능명>` | `pm/analytics-dashboard` |
| `po/<기능명>` | `po/user-story-update` |
| `hotfix/<버그명>` | `hotfix/crash-on-launch` |

### 세션 역할

`.claude/role` 파일에서 현재 역할을 읽는다. 파일이 없으면 `dev`를 기본값으로 사용.

```
# .claude/role 파일 형식 (한 줄, 값만 기재)
dev
```

사용 가능한 역할: `dev` | `design` | `pm` | `po`

### 역할별 규칙

| 역할 | 브랜치 접두사 | qa 반영 방식 | 안전 규칙 |
|---|---|---|---|
| `dev` | `dev/<기능명>` | 직접 머지 | 기본 |
| `design` | `design/<기능명>` | PR (qa 대상) | 비개발자 안전 규칙 |
| `pm` | `pm/<기능명>` | PR (qa 대상) | 비개발자 안전 규칙 |
| `po` | `po/<기능명>` | PR (qa 대상) | 비개발자 안전 규칙 |

- 핫픽스(`hotfix/*`)는 `dev` 역할에서만 허용

### 비개발자 안전 규칙 (design, pm, po)

`design`, `pm`, `po` 역할에서는 다음 규칙이 자동 적용된다:

#### 절대 금지
- **보호 브랜치 작업 금지**: `main`, `qa`에 직접 커밋/머지/rebase
- **빌드 설정 파일 수정 금지**: `.env`, `Podfile`, `Package.swift`, `*.pbxproj`, `*.xcworkspace`, `fastlane/`, `Gemfile`
- **인증서/시크릿 파일 커밋 금지**: `*.p12`, `*.mobileprovision`, `*.cer`, `*.pem`

#### 위험 파일 자동 제외 (submit 시)
- `.env`, `.env.*`
- `*.p12`, `*.mobileprovision`, `*.cer`
- `Podfile`, `Podfile.lock`
- `Package.swift`, `Package.resolved`
- `*.pbxproj`, `*.xcworkspace`
- `fastlane/`, `Gemfile*`

### 플로우 규칙

- **모든 작업 브랜치는 `qa`에서 생성**
- 개발 완료 후 `qa`에 반영 (방식은 역할별 규칙에 따름)
- **배포** — 마켓 배포 완료 후 `qa` → `main` 머지
- **핫픽스** — `main` → `hotfix/<버그명>` → 수정 후 `main` 직접 머지 (dev 역할만 가능)

## Common Commands

### 개발 시작
```bash
git checkout qa
git pull origin qa
git checkout -b dev/push-notification
```

### 핫픽스 시작
```bash
git checkout main
git pull origin main
git checkout -b hotfix/crash-on-launch
```

### Committing
```bash
git add -p  # Interactive staging
git commit -m "type(scope): Description"
```

### 개발 완료 후 qa 머지
```bash
git checkout qa
git pull origin qa
git merge dev/push-notification
git push origin qa
```

### 핫픽스 완료
```bash
git checkout main
git merge hotfix/crash-on-launch
git push origin main
```

## Pull Request Guidelines

### Title
Follow commit message format for the title.

### Description Template
```markdown
## Summary
Brief description of what this PR does.

## Changes
- Change 1
- Change 2

## Testing
How was this tested?

## Checklist
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] No breaking changes
```
