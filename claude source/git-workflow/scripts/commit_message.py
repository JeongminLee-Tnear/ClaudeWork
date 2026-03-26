#!/usr/bin/env python3
"""Validate or generate conventional commit messages.

Usage:
    ./commit_message.py validate "feat: Add new feature"
    ./commit_message.py generate feat "Add user authentication"
    ./commit_message.py types
"""

import json
import sys

COMMIT_TYPES = {
    "feat": "새로운 기능에 대한 커밋",
    "fix": "버그 수정에 대한 커밋",
    "build": "빌드 관련 파일 수정에 대한 커밋",
    "chore": "그 외 자잘한 수정에 대한 커밋",
    "ci": "CI관련 설정 수정에 대한 커밋",
    "docs": "문서 수정에 대한 커밋",
    "style": "코드 스타일 혹은 포맷 등에 관한 커밋",
    "refactor": "코드 리팩토링에 대한 커밋",
    "test": "테스트 코드 수정에 대한 커밋",
    "release": "배포 관련 수정에 대한 커밋",
}


def validate(message: str) -> dict:
    """Validate a commit message."""
    errors = []
    warnings = []

    lines = message.strip().split("\n")
    if not lines or not lines[0]:
        return {"valid": False, "errors": ["Empty commit message"]}

    subject = lines[0]

    # Check format: type: description
    if ":" not in subject:
        errors.append("Missing ':' separator (expected 'type: description')")
    else:
        type_part, desc = subject.split(":", 1)
        type_part = type_part.strip().rstrip("!").split("(")[0]
        desc = desc.strip()

        if type_part not in COMMIT_TYPES:
            errors.append(
                f"Unknown type '{type_part}'. Valid: {', '.join(COMMIT_TYPES.keys())}"
            )

        if not desc:
            errors.append("Description required after ':'")

        if desc and desc[0].islower():
            warnings.append("Subject first letter should be capitalized")

        if subject.endswith("."):
            warnings.append("Subject should not end with a period")

        if len(subject) > 50:
            warnings.append(f"Subject is {len(subject)} chars (recommended: ≤50)")

    # Check body line length
    if len(lines) > 2:
        if lines[1].strip():
            warnings.append("Second line should be blank (separator between subject and body)")
        for i, line in enumerate(lines[2:], start=3):
            if len(line) > 72:
                warnings.append(f"Line {i} is {len(line)} chars (recommended: ≤72)")

    return {"valid": len(errors) == 0, "errors": errors, "warnings": warnings}


def generate(commit_type: str, description: str, scope: str = None) -> dict:
    """Generate a commit message."""
    if commit_type not in COMMIT_TYPES:
        return {
            "error": f"Unknown type '{commit_type}'. Valid: {', '.join(COMMIT_TYPES.keys())}"
        }

    if scope:
        message = f"{commit_type}({scope}): {description}"
    else:
        message = f"{commit_type}: {description}"

    return {"message": message, "type": commit_type, "description": description}


def list_types() -> dict:
    """List all valid commit types."""
    return {"types": COMMIT_TYPES}


if __name__ == "__main__":
    try:
        if len(sys.argv) < 2:
            print(
                json.dumps(
                    {
                        "error": "Usage: commit_message.py <validate|generate|types> [args]"
                    }
                )
            )
            sys.exit(1)

        command = sys.argv[1]

        if command == "validate":
            msg = sys.argv[2] if len(sys.argv) > 2 else sys.stdin.read()
            result = validate(msg)
        elif command == "generate":
            if len(sys.argv) < 4:
                result = {
                    "error": "Usage: commit_message.py generate <type> <description> [scope]"
                }
            else:
                commit_type = sys.argv[2]
                description = sys.argv[3]
                scope = sys.argv[4] if len(sys.argv) > 4 else None
                result = generate(commit_type, description, scope)
        elif command == "types":
            result = list_types()
        else:
            result = {
                "error": f"Unknown command '{command}'. Use: validate, generate, types"
            }

        print(json.dumps(result, indent=2, ensure_ascii=False))
    except Exception as e:
        print(json.dumps({"error": str(e)}))
