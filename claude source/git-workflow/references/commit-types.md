# Commit Types Reference

## Types

| Type | Description | Example |
|------|-------------|---------|
| `feat` | 새로운 기능에 대한 커밋 | `feat(cart): Add checkout button` |
| `fix` | 버그 수정에 대한 커밋 | `fix(login): Correct password validation` |
| `build` | 빌드 관련 파일 수정에 대한 커밋 | `build(docker): Optimize image size` |
| `chore` | 그 외 자잘한 수정에 대한 커밋 | `chore(deps): Update lodash to 4.17.21` |
| `ci` | CI관련 설정 수정에 대한 커밋 | `ci(github): Add lint workflow` |
| `docs` | 문서 수정에 대한 커밋 | `docs(readme): Update installation steps` |
| `style` | 코드 스타일 혹은 포맷 등에 관한 커밋 | `style(api): Format with prettier` |
| `refactor` | 코드 리팩토링에 대한 커밋 | `refactor(auth): Simplify token logic` |
| `test` | 테스트 코드 수정에 대한 커밋 | `test(api): Add user endpoint tests` |
| `release` | 배포 관련 수정에 대한 커밋 | `release(v2.1.0): Prepare market release` |

## Scope Examples

Scopes should be short and identify the area of the codebase:

- `auth` - Authentication module
- `api` - API endpoints
- `ui` - User interface
- `db` - Database
- `config` - Configuration
- `deps` - Dependencies
- `core` - Core functionality

## Breaking Changes

Use `!` after type/scope for breaking changes:

```
feat(api)!: Change response format

BREAKING CHANGE: Response now uses camelCase instead of snake_case.
Migration guide available in docs/migration-v2.md
```

## 커밋 메시지 작성 규칙

- 제목과 본문을 빈 행으로 구분한다
- 제목을 50글자 내로 제한
- 제목 첫 글자는 대문자로 작성
- 제목 끝에 마침표 넣지 않기
- 제목은 명령문으로 사용하며 과거형을 사용하지 않는다
- 본문의 각 행은 72글자 내로 제한
- 어떻게 보다는 무엇과 왜를 설명한다

## Footer

바닥글은 이슈 참조 정보를 추가하는 용도로 사용합니다.

- `Closes #123` — 이슈를 참조하면서 main 브랜치로 푸시될 때 이슈를 닫음
- `Fixes #456` — 버그 이슈 참조
- `Refs #789` — 단순 참조

## Multi-line Commits

```
feat(search): Implement fuzzy matching

Added fuzzy matching algorithm to improve search results.
Users can now find items even with typos or partial matches.

- Implemented Levenshtein distance calculation
- Added configurable threshold for match sensitivity
- Updated search index to support fuzzy queries

Closes #789
```
