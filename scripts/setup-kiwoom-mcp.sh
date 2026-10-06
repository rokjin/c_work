#!/usr/bin/env bash
# 키움 MCP(kiwoom-spec / kiwoom-exec) 로컬 설치 — SessionStart 훅에서 실행
# 참고: https://github.com/Kiwoom-Securities/Kiwoom-REST-API/blob/main/SETUP-MCP.md
set -euo pipefail

REPO_URL="https://github.com/Kiwoom-Securities/Kiwoom-REST-API"
REPO_PATH="${KIWOOM_REPO_PATH:-$HOME/.local/share/mcp/Kiwoom-REST-API}"

# uv 확보 (없으면 설치)
if ! command -v uv >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/uv" ]; then
  curl -LsSf https://astral.sh/uv/install.sh | sh >&2
fi
UV="$(command -v uv || echo "$HOME/.local/bin/uv")"

# repository 준비 (기존 clone은 건드리지 않음)
if [ ! -d "$REPO_PATH/.git" ]; then
  mkdir -p "$(dirname "$REPO_PATH")"
  git clone --depth 1 "$REPO_URL" "$REPO_PATH" >&2
fi

# 의존성 미리 설치 (첫 기동 timeout 방지)
"$UV" sync --frozen --quiet --directory "$REPO_PATH/mcp_spec" >&2
"$UV" sync --frozen --quiet --directory "$REPO_PATH/mcp_exec" >&2
