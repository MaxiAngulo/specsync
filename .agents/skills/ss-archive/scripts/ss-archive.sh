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

root_key() {
  local root="$1"
  local key
  key="$(printf '%s' "$root" | sed -E 's#[:/\\ ]+#__#g; s#[^A-Za-z0-9._-]#_#g; s#^_+##; s#_+$##')"
  printf '%s\n' "${key:-root}"
}

proposal_source_dir() {
  local proposal_dir="$1"
  local source_root="$2"
  if [[ "$source_root" = /* ]] || [[ "$source_root" =~ ^[A-Za-z]:[\\/].* ]]; then
    printf '%s/%s\n' "$proposal_dir" "$(root_key "$source_root")"
  else
    printf '%s/%s\n' "$proposal_dir" "$source_root"
  fi
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../../../.." && pwd)"
proposes_dir="$repo_root/proposes"
archive_dir="$repo_root/proposals-archive"
specsync_dir="$repo_root/.specsync"
sessions_dir="$specsync_dir/sessions"
session_id="$(get_session_id "${2:-}")"
session_file="$sessions_dir/$session_id.json"
source_roots_file="$specsync_dir/source-roots.txt"

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

archived_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

if command -v git >/dev/null 2>&1; then
  mkdir -p "$destination"

  [[ -f "$proposal_dir/proposal.md" ]] && cp "$proposal_dir/proposal.md" "$destination/proposal.md"

  patch_file="$destination/changes.patch"

  append_diff() {
    local live_file="$1"
    local proposal_file="$2"
    local diff_output
    diff_output="$(git diff --no-index -- "$live_file" "$proposal_file" 2>/dev/null || true)"
    if [[ -n "$diff_output" ]]; then
      printf '%s\n' "$diff_output" >> "$patch_file"
    fi
  }

  if [[ -d "$proposal_dir/specs" ]]; then
    while IFS= read -r proposal_file; do
      [[ -n "$proposal_file" ]] || continue
      rel_path="${proposal_file#"$proposal_dir/specs/"}"
      live_file="$repo_root/specs/$rel_path"
      if [[ -f "$live_file" ]]; then
        append_diff "$live_file" "$proposal_file"
      else
        append_diff /dev/null "$proposal_file"
      fi
    done < <(find "$proposal_dir/specs" -type f | LC_ALL=C sort)
  fi

  while IFS= read -r source_root || [[ -n "$source_root" ]]; do
    source_root="${source_root%%#*}"
    source_root="${source_root//[[:space:]]/}"
    [[ -z "$source_root" ]] && continue
    proposal_root_dir="$(proposal_source_dir "$proposal_dir" "$source_root")"
    [[ -d "$proposal_root_dir" ]] || continue
    if [[ "$source_root" = /* ]] || [[ "$source_root" =~ ^[A-Za-z]:[\\/].* ]]; then
      live_root="$source_root"
    else
      live_root="$repo_root/$source_root"
    fi
    while IFS= read -r proposal_file; do
      [[ -n "$proposal_file" ]] || continue
      rel_path="${proposal_file#"$proposal_root_dir/"}"
      live_file="$live_root/$rel_path"
      if [[ -f "$live_file" ]]; then
        append_diff "$live_file" "$proposal_file"
      else
        append_diff /dev/null "$proposal_file"
      fi
    done < <(find "$proposal_root_dir" -type f | LC_ALL=C sort)
  done < <(
    if [[ -f "$source_roots_file" ]]; then
      awk 'NF { print $0 }' "$source_roots_file"
    else
      printf 'src\n'
    fi
  )

  deletions_file="$proposal_dir/deletions.txt"
  if [[ -f "$deletions_file" ]]; then
    while IFS= read -r deletion_path || [[ -n "$deletion_path" ]]; do
      deletion_path="${deletion_path%%#*}"
      deletion_path="${deletion_path//[[:space:]]/}"
      [[ -z "$deletion_path" ]] && continue
      if [[ "$deletion_path" == *..* ]] || [[ "$deletion_path" = /* ]] || [[ "$deletion_path" =~ ^[A-Za-z]:[\\/].* ]]; then
        continue
      fi
      live_file="$repo_root/$deletion_path"
      [[ -f "$live_file" ]] || continue
      append_diff "$live_file" /dev/null
    done < "$deletions_file"
  fi

  cat <<EOF > "$destination/proposal.json"
{
  "proposal_name": "$proposal_name",
  "proposal_path": "proposals-archive/$proposal_name",
  "status": "archived",
  "archive_format": "patch",
  "archived_at": "$archived_at"
}
EOF

  rm -rf "$proposal_dir"
else
  mv "$proposal_dir" "$destination"

  cat <<EOF > "$destination/proposal.json"
{
  "proposal_name": "$proposal_name",
  "proposal_path": "proposals-archive/$proposal_name",
  "status": "archived",
  "archive_format": "folder",
  "archived_at": "$archived_at"
}
EOF
fi

if [[ -d "$sessions_dir" ]]; then
  for bound_session in "$sessions_dir"/*.json; do
    [[ -f "$bound_session" ]] || continue
    bound_path="$(session_field "$bound_session" "proposal_path")"
    if [[ "$bound_path" == "proposes/$proposal_name" ]]; then
      rm -f "$bound_session"
    fi
  done
fi

printf '%s\n' "$destination"
