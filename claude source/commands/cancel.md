작업 취소 — `/start`로 생성한 브랜치를 삭제하고 qa 브랜치로 복귀합니다.

## 필수 스킬

이 커맨드 실행 시 반드시 `git-workflow` + `branch-role` 스킬을 먼저 로드할 것.

## 사전 체크 (하나라도 실패 시 중단)

1. `branch-role` 스킬의 **"세션 역할"** 확인 (`.claude/role` 파일 읽기, 없으면 `dev`)
2. **현재 브랜치 확인**: `git branch --show-current`
3. **보호 브랜치 차단**: `main`, `qa`에서는 실행 금지
   - "⛔ 보호 브랜치에서는 /cancel을 실행할 수 없습니다."
4. **역할 브랜치 확인**: 현재 브랜치가 역할에 맞는 작업 브랜치인지 확인
   - `dev` → `dev/*` 또는 `hotfix/*`
   - `design` → `design/*`
   - `pm` → `pm/*`
   - `po` → `po/*`
   - 역할과 다른 브랜치면 경고 후 계속 진행할지 확인

## 실행 절차

### 1단계: 상태 확인 및 경고

`git status`와 `git log --oneline qa..HEAD`로 변경사항 확인 후 사용자에게 표시:

```
⚠️ 작업 취소 확인
🔀 삭제할 브랜치: {branch_name}
📝 커밋 {n}개가 삭제됩니다:
  - {commit1}
  - {commit2}
📁 커밋되지 않은 변경: {count}개 파일
❓ 정말 취소하시겠습니까? (모든 변경사항이 영구 삭제됩니다)
```

- 커밋도 없고 변경사항도 없으면 경고 없이 바로 진행

### 2단계: 사용자 확인 후 실행

**반드시 사용자의 명시적 확인을 받은 후 실행.**

```bash
# 커밋되지 않은 변경사항 버리기
git checkout -- .
git clean -fd

# qa 브랜치로 전환
git checkout qa
git pull origin qa

# 작업 브랜치 삭제 (로컬)
git branch -D {branch_name}
```

### 3단계: 리모트 브랜치 정리

리모트에 해당 브랜치가 존재하는지 확인:
```bash
git ls-remote --heads origin {branch_name}
```

- 존재하면 삭제할지 사용자에게 질문
- 확인 시: `git push origin --delete {branch_name}`

## 출력 포맷

```
🗑️ 작업 취소 완료!
🔀 삭제된 브랜치: {branch_name}
📍 현재 브랜치: qa
💡 새 작업을 시작하려면 /start를 실행하세요.
```

## $ARGUMENTS 처리

- `$ARGUMENTS`에 "force" 또는 "강제"가 포함되면 확인 질문 없이 바로 실행 (리모트 삭제 제외)
