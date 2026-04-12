#!/usr/bin/env bash

set -euo pipefail

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

session_field() {
  local session_file="$1"
  local field_name="$2"
  awk -F'"' -v field_name="$field_name" '$2 == field_name { print $4; exit }' "$session_file"
}

write_session_binding() {
  local session_file="$1"
  local session_id="$2"
  local proposal_name="$3"
  local proposal_path="$4"
  local now="$5"
  local created_at="$now"

  if [[ -f "$session_file" ]]; then
    created_at="$(session_field "$session_file" "created_at")"
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

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../../../.." && pwd)"
proposes_dir="$repo_root/proposes"
specsync_dir="$repo_root/.specsync"
sessions_dir="$specsync_dir/sessions"

proposal_input="${1:-}"
request_input="${2:-Use the current user request from the conversation.}"
session_id="$(get_session_id "${3:-}")"
session_file="$sessions_dir/$session_id.json"
mkdir -p "$specsync_dir" "$sessions_dir"
if [[ -n "$proposal_input" ]]; then
  if [[ -d "$proposal_input" ]]; then
    proposal_dir="$(cd "$proposal_input" && pwd)"
  else
    proposal_dir="$proposes_dir/$proposal_input"
  fi
  if [[ ! -d "$proposal_dir" ]]; then
    echo "Proposal not found: $proposal_input" >&2
    exit 1
  fi
  write_session_binding "$session_file" "$session_id" "$(basename "$proposal_dir")" "${proposal_dir#$repo_root/}" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
else
  if [[ ! -f "$session_file" ]]; then
    echo "No proposal is bound to the current SpecSync session." >&2
    exit 1
  fi
  proposal_path="$(session_field "$session_file" "proposal_path")"
  if [[ -z "$proposal_path" ]]; then
    echo "No proposal is bound to the current SpecSync session." >&2
    exit 1
  fi

  if [[ "$proposal_path" = /* ]] || [[ "$proposal_path" =~ ^[A-Za-z]:[\\/].* ]]; then
    proposal_dir="$proposal_path"
  else
    proposal_dir="$repo_root/$proposal_path"
  fi
fi

proposal_name="$(basename "$proposal_dir")"
cat <<EOF > "$proposal_dir/orchestration.md"
# Orchestration

- Session id: $session_id
- Session binding: .specsync/sessions/$session_id.json
- Bound proposal: $proposal_name
- Orchestrator agent: .specsync/agents/specsync-orchestrator/AGENT.md
- Orchestrator input: $request_input
- Managed spec root: specs/<matching-path> when a spec delta is needed
- Managed source roots: <source-root>/<matching-path> for relative roots and <root-key>/<matching-path> for absolute or external roots
- Support skill routing: inspect .specsync/skills and ask each relevant skill whether its owned files need deltas.
- Source routing: use .specsync/skills/specsync-source-code/SKILL.md for proposal-folder source deltas.
- Consistency rule: do not leave proposal-folder spec and source deltas with contradictory behavior.
EOF

printf '%s\n' "$proposal_dir"

