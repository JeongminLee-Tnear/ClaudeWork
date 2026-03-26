---
name: branch-role
description: 프로젝트 역할 기반 브랜치 규칙. /start, /submit 및 모든 Git 작업 시 git-workflow와 함께 자동 로드.
---

# 역할 기반 브랜치 규칙

이 스킬은 `git-workflow` 스킬을 확장하여 프로젝트별 역할 규칙을 적용한다.
Git 작업 시 `git-workflow`와 함께 반드시 로드할 것.

## 세션 역할

`.claude/role` 파일에서 현재 역할을 읽는다. 파일이 없으면 `dev`를 기본값으로 사용.

```
# .claude/role 파일 형식 (한 줄, 값만 기재)
dev
```

사용 가능한 역할: `dev` | `design` | `pm` | `po`

## 역할별 규칙

| 역할 | 브랜치 접두사 | qa 반영 방식 | 안전 규칙 |
|---|---|---|---|
| `dev` | `dev/<기능명>` | 직접 머지 | 기본 |
| `design` | `design/<기능명>` | PR (qa 대상) | 비개발자 안전 규칙 |
| `pm` | `pm/<기능명>` | PR (qa 대상) | 비개발자 안전 규칙 |
| `po` | `po/<기능명>` | PR (qa 대상) | 비개발자 안전 규칙 |

- 핫픽스(`hotfix/*`)는 `dev` 역할에서만 허용

## 비개발자 안전 규칙 (design, pm, po)

`design`, `pm`, `po` 역할에서는 다음 규칙이 자동 적용된다:

### 절대 금지
- **보호 브랜치 작업 금지**: `main`, `qa`에 직접 커밋/머지/rebase
- **빌드 설정 파일 수정 금지**: `.env`, `Podfile`, `Package.swift`, `*.pbxproj`, `*.xcworkspace`, `fastlane/`, `Gemfile`
- **인증서/시크릿 파일 커밋 금지**: `*.p12`, `*.mobileprovision`, `*.cer`, `*.pem`

### 위험 파일 자동 제외 (submit 시)
- `.env`, `.env.*`
- `*.p12`, `*.mobileprovision`, `*.cer`
- `Podfile`, `Podfile.lock`
- `Package.swift`, `Package.resolved`
- `*.pbxproj`, `*.xcworkspace`
- `fastlane/`, `Gemfile*`
