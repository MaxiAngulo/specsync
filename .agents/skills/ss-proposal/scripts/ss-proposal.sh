#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: ss-proposal.sh <kebab-case-name> [session-id]" >&2
  exit 1
fi

get_session_id() {
  local session_input="${1:-}"
  local candidate
  for candidate in "$session_input" "${SPECSYNC_SESSION_ID:-}" "${SPEC_SYNC_SESSION_ID:-}" "${AGENT_SESSION_ID:-}" "${CHAT_SESSION_ID:-}" "${SESSION_ID:-}" "${THREAD_ID:-}"; do
    if [[ -n "${candidate// /}" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  echo "No SpecSync session id configured. Pass a session id or set SPECSYNC_SESSION_ID." >&2
  exit 1
}

write_session_binding() {
  local session_file="$1"
  local session_id="$2"
  local proposal_name="$3"
  local proposal_path="$4"
  local now="$5"
  local created_at="$now"

  if [[ -f "$session_file" ]]; then
    created_at="$(awk -F'"' '$2 == "created_at" { print $4; exit }' "$session_file")"
    if [[ -z "$created_at" ]]; then
      created_at="$now"
    fi
  fi

  cat <<EOF > "$session_file"
{
  "session_id": "$session_id",
  "proposal_name": "$proposal_name",
  "proposal_path": "$proposal_path",
  "created_at": "$created_at",
  "updated_at": "$now"
}
EOF
}

name="$1"
session_id="$(get_session_id "${2:-}")"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../../../.." && pwd)"
proposes_dir="$repo_root/proposes"
specsync_dir="$repo_root/.specsync"
sessions_dir="$specsync_dir/sessions"
session_file="$sessions_dir/$session_id.json"
timestamp="$(date -u +"%y%m%dT%H%M")"
target_dir="$proposes_dir/$timestamp-$name"
created_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
mkdir -p "$target_dir" "$specsync_dir" "$sessions_dir"

cat <<EOF > "$target_dir/proposal.json"
{
  "proposal_name": "$timestamp-$name",
  "proposal_path": "proposes/$timestamp-$name",
  "status": "open",
  "created_at": "$created_at"
}
EOF

write_session_binding "$session_file" "$session_id" "$timestamp-$name" "proposes/$timestamp-$name" "$created_at"
printf '%s\n' "$target_dir"

