세션 시작 — `branch-role` 스킬의 "세션 역할" 설정에 따라 동작합니다.

## 필수 스킬

이 커맨드 실행 시 반드시 `git-workflow` + `branch-role` 스킬을 먼저 로드할 것.

## 절차

1. `git-workflow` 스킬 로드
2. `branch-role` 스킬의 **"세션 역할"** 확인 (`.claude/role` 파일 읽기)
3. **qa 브랜치 최신화** (항상 실행):
   ```bash
   git fetch origin qa
   ```
4. 현재 브랜치 확인 (`git branch --show-current`)
5. 보호 브랜치(`main`, `qa`) 여부 판별

### 보호 브랜치인 경우

사용자에게 작업 내용을 질문한 후 브랜치 생성:

```bash
git checkout qa
git pull origin qa
git checkout -b {역할}/{기능명}
```
- qa 최신 상태에서 브랜치를 생성하므로 fetch는 이미 완료된 상태

- `dev` 역할 → `dev/{기능명}`
- `design` 역할 → `design/{기능명}`
- `pm` 역할 → `pm/{기능명}`
- `po` 역할 → `po/{기능명}`

**⚠️ 브랜치 접두사는 반드시 `branch-role` 스킬의 "세션 역할"을 따른다.**
작업 내용(디자인, 기획 등)과 무관하게 역할 접두사를 변경하지 말 것.
예: `dev` 역할이 디자인 관련 작업을 해도 `dev/design-refresh`로 생성 (절대 `design/` 접두사 사용 금지)

### 이미 역할에 맞는 작업 브랜치인 경우

현재 상태(변경 파일 수, 마지막 커밋) 표시 후 계속 작업 안내.

### 역할과 다른 접두사 브랜치인 경우

경고 후 올바른 브랜치로 전환할지 질문.

## 핫픽스 (dev 역할만)

`$ARGUMENTS`에 "hotfix"가 포함되면:
```bash
git checkout main
git pull origin main
git checkout -b hotfix/{버그명}
```

## 비개발자 안전 규칙 (design, pm, po 역할)

세션 시작 시 안전 규칙 활성화를 안내:
- 빌드 설정 파일 수정 금지
- 인증서/시크릿 파일 커밋 금지
- 보호 브랜치에 직접 커밋/머지 금지

## 사용자 인자

$ARGUMENTS가 있으면 해당 설명으로 브랜치명 자동 생성 (질문 생략).
예: `/start push-notification` → `dev/push-notification` (dev 역할일 때)

## 출력 포맷

```
✅ {역할} 브랜치에서 작업 중: {branch_name}
📁 변경된 파일: {count}개
🔀 베이스: qa
🛡️ 비개발자 안전 규칙 활성화됨        ← design/pm/po만
💡 완료되면 /submit으로 제출합니다.
```
