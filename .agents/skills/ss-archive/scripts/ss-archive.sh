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

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../../../.." && pwd)"
proposes_dir="$repo_root/proposes"
archive_dir="$repo_root/proposals-archive"
specsync_dir="$repo_root/.specsync"
sessions_dir="$specsync_dir/sessions"
session_id="$(get_session_id "${2:-}")"
session_file="$sessions_dir/$session_id.json"

proposal_input="${1:-}"
if [[ -n "$proposal_input" ]]; then
  if [[ -d "$proposal_input" ]]; then
    proposal_dir="$(cd "$proposal_input" && pwd)"
  else
    proposal_dir="$proposes_dir/$proposal_input"
  fi
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

if [[ ! -d "$proposal_dir" ]]; then
  echo "Proposal not found: $proposal_dir" >&2
  exit 1
fi

mkdir -p "$archive_dir"
proposal_name="$(basename "$proposal_dir")"
destination="$archive_dir/$proposal_name"

if [[ -e "$destination" ]]; then
  echo "Archive destination already exists: $destination" >&2
  exit 1
fi

mv "$proposal_dir" "$destination"

if [[ -f "$destination/proposal.json" ]]; then
  cat <<EOF > "$destination/proposal.json"
{
  "proposal_name": "$proposal_name",
  "proposal_path": "proposals-archive/$proposal_name",
  "status": "archived",
  "archived_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
fi

if [[ -d "$sessions_dir" ]]; then
  for bound_session in "$sessions_dir"/*.json; do
    [[ -f "$bound_session" ]] || continue
    proposal_path="$(session_field "$bound_session" "proposal_path")"
    if [[ "$proposal_path" == "proposes/$proposal_name" ]]; then
      rm -f "$bound_session"
    fi
  done
fi

printf '%s\n' "$destination"
