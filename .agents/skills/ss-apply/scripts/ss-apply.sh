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

hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
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

root_state_lines() {
  local source_root="$1"
  local directory_path="$2"

  if [[ ! -d "$directory_path" ]]; then
    printf 'root\t%s\tmissing\n' "$source_root"
    return 0
  fi

  printf 'root\t%s\tpresent\n' "$source_root"
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    local rel_path="${file#"$directory_path"/}"
    printf 'file\t%s\t%s\t%s\n' "$source_root" "$rel_path" "$(hash_file "$file")"
  done < <(find "$directory_path" -type f | LC_ALL=C sort)
}

manifest_root_lines() {
  local manifest_path="$1"
  local source_root="$2"
  if [[ ! -f "$manifest_path" ]]; then
    return 0
  fi

  awk -F'\t' -v root="$source_root" '($1 == "root" || $1 == "file") && $2 == root { print }' "$manifest_path"
}

overlay_directory() {
  local source_dir="$1"
  local dest_dir="$2"

  [[ -d "$source_dir" ]] || return 0
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    local rel_path="${file#"$source_dir"/}"
    mkdir -p "$(dirname "$dest_dir/$rel_path")"
    cp "$file" "$dest_dir/$rel_path"
  done < <(find "$source_dir" -type f | LC_ALL=C sort)
}

write_source_state_manifest() {
  local proposal_dir="$1"
  shift

  {
    printf 'captured_at\t%s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    while [[ $# -gt 0 ]]; do
      local source_root="$1"
      local source_dir="$2"
      shift 2
      root_state_lines "$source_root" "$source_dir"
    done
  } > "$proposal_dir/source-state.txt"
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../../../.." && pwd)"
proposes_dir="$repo_root/proposes"
specsync_dir="$repo_root/.specsync"
sessions_dir="$specsync_dir/sessions"
session_id="$(get_session_id "${2:-}")"
session_file="$sessions_dir/$session_id.json"
source_roots_file="$repo_root/.specsync/source-roots.txt"
specs_dir="$repo_root/specs"

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

mapfile -t source_roots < <(
  if [[ -f "$source_roots_file" ]]; then
    awk 'NF { print $0 }' "$source_roots_file"
  else
    printf 'src\n'
  fi
)

proposal_source_roots=()
proposal_source_dirs=()
for source_root in "${source_roots[@]}"; do
  proposal_root_dir="$(proposal_source_dir "$proposal_dir" "$source_root")"
  if [[ -d "$proposal_root_dir" ]]; then
    proposal_source_roots+=("$source_root")
    proposal_source_dirs+=("$proposal_root_dir")
  fi
done

if [[ ${#proposal_source_roots[@]} -gt 0 ]]; then
  manifest_path="$proposal_dir/source-state.txt"
  if [[ ! -f "$manifest_path" ]]; then
    echo "Proposal source changes require a live source snapshot. Run ss-pull before ss-apply." >&2
    exit 1
  fi

  changed_roots=()
  for i in "${!proposal_source_roots[@]}"; do
    source_root="${proposal_source_roots[$i]}"
    if [[ "$source_root" = /* ]] || [[ "$source_root" =~ ^[A-Za-z]:[\\/].* ]]; then
      destination="$source_root"
    else
      destination="$repo_root/$source_root"
    fi

    current_lines="$(root_state_lines "$source_root" "$destination")"
    baseline_lines="$(manifest_root_lines "$manifest_path" "$source_root")"
    if [[ "$current_lines" != "$baseline_lines" ]]; then
      changed_roots+=("$source_root")
    fi
  done

  if [[ ${#changed_roots[@]} -gt 0 ]]; then
    echo "Live source roots changed since the last ss-pull. Run ss-pull before ss-apply: ${changed_roots[*]}" >&2
    exit 1
  fi
fi

overlay_directory "$proposal_dir/specs" "$specs_dir"

for i in "${!proposal_source_roots[@]}"; do
  source_root="${proposal_source_roots[$i]}"
  proposal_root_dir="${proposal_source_dirs[$i]}"
  if [[ "$source_root" = /* ]] || [[ "$source_root" =~ ^[A-Za-z]:[\\/].* ]]; then
    destination="$source_root"
  else
    destination="$repo_root/$source_root"
  fi
  overlay_directory "$proposal_root_dir" "$destination"
done

if [[ ${#proposal_source_roots[@]} -gt 0 ]]; then
  manifest_args=()
  for source_root in "${proposal_source_roots[@]}"; do
    if [[ "$source_root" = /* ]] || [[ "$source_root" =~ ^[A-Za-z]:[\\/].* ]]; then
      destination="$source_root"
    else
      destination="$repo_root/$source_root"
    fi
    manifest_args+=("$source_root" "$destination")
  done
  write_source_state_manifest "$proposal_dir" "${manifest_args[@]}"
fi

checked_roots="none"
if [[ ${#proposal_source_roots[@]} -gt 0 ]]; then
  checked_roots="${proposal_source_roots[*]}"
fi

cat <<EOF > "$proposal_dir/apply-summary.md"
# Apply Summary

- Status: applied
- Applied UTC: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
- Proposal: $(basename "$proposal_dir")
- Live source guard: passed
- Checked source roots: $checked_roots
EOF

printf '%s\n' "$proposal_dir"
