#!/usr/bin/env bash

set -euo pipefail

if [[ $# -gt 2 ]]; then
  echo "Usage: ss-pull.sh [proposal-name-or-path] [session-id]" >&2
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

replace_directory() {
  local source_dir="$1"
  local dest_dir="$2"

  rm -rf "$dest_dir"
  if [[ -d "$source_dir" ]]; then
    mkdir -p "$dest_dir"
    cp -R "$source_dir"/. "$dest_dir"/
  fi
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

line_merge_key() {
  local line="$1"
  local trimmed
  trimmed="$(printf '%s' "$line" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  [[ -n "$trimmed" ]] || return 1

  if [[ "$trimmed" =~ ^#+[[:space:]]+(.+)$ ]]; then
    printf 'heading:%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi

  if [[ "$trimmed" =~ ^([-*]|[0-9]+\.)[[:space:]]+(.+)$ ]]; then
    local body="${BASH_REMATCH[2]}"
    if [[ "$body" =~ ^([^:]+): ]]; then
      printf 'item:%s\n' "${BASH_REMATCH[1]}"
      return 0
    fi
    if [[ "$body" =~ ^(.+\?) ]]; then
      printf 'item:%s\n' "${BASH_REMATCH[1]}"
      return 0
    fi
  fi

  return 1
}

merge_keyed_markdown_line() {
  local proposal_line="$1"
  local live_line="$2"

  if [[ "$proposal_line" == "$live_line" ]]; then
    printf '%s\n' "$proposal_line"
    return 0
  fi

  if printf '%s' "$proposal_line" | grep -Fq -- "$live_line"; then
    printf '%s\n' "$proposal_line"
    return 0
  fi

  if printf '%s' "$live_line" | grep -Fq -- "$proposal_line"; then
    printf '%s\n' "$live_line"
    return 0
  fi

  if [[ "$proposal_line" == *:* && "$live_line" == *:* ]]; then
    local proposal_prefix="${proposal_line%%:*}"
    local proposal_value="${proposal_line#*:}"
    local live_prefix="${live_line%%:*}"
    local live_value="${live_line#*:}"

    proposal_prefix="$(printf '%s' "$proposal_prefix" | sed -E 's/[[:space:]]+$//')"
    live_prefix="$(printf '%s' "$live_prefix" | sed -E 's/[[:space:]]+$//')"
    proposal_value="$(printf '%s' "$proposal_value" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    live_value="$(printf '%s' "$live_value" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"

    if [[ "$proposal_prefix" == "$live_prefix" ]]; then
      if [[ -z "$proposal_value" ]]; then
        printf '%s\n' "$live_line"
        return 0
      fi
      if [[ -z "$live_value" ]]; then
        printf '%s\n' "$proposal_line"
        return 0
      fi
      if [[ "$proposal_value" == "$live_value" ]]; then
        printf '%s\n' "$proposal_line"
        return 0
      fi
      if printf '%s' "$proposal_value" | grep -Fq -- "$live_value"; then
        printf '%s\n' "$proposal_line"
        return 0
      fi
      if printf '%s' "$live_value" | grep -Fq -- "$proposal_value"; then
        printf '%s\n' "$live_line"
        return 0
      fi
    fi
  fi

  return 1
}

bootstrap_merge_markdown_file() {
  local proposal_file="$1"
  local live_file="$2"

  mapfile -t output_lines < "$proposal_file"
  while IFS= read -r live_line || [[ -n "$live_line" ]]; do
    local exact_found=0
    for existing_line in "${output_lines[@]}"; do
      if [[ "$existing_line" == "$live_line" ]]; then
        exact_found=1
        break
      fi
    done
    [[ $exact_found -eq 1 ]] && continue

    local merge_key=""
    if merge_key="$(line_merge_key "$live_line" 2>/dev/null)"; then
      local found_index=-1
      for i in "${!output_lines[@]}"; do
        local current_key=""
        if current_key="$(line_merge_key "${output_lines[$i]}" 2>/dev/null)"; then
          if [[ "$current_key" == "$merge_key" ]]; then
            found_index="$i"
            break
          fi
        fi
      done

      if [[ $found_index -ge 0 ]]; then
        local merged_line=""
        if ! merged_line="$(merge_keyed_markdown_line "${output_lines[$found_index]}" "$live_line")"; then
          return 1
        fi
        output_lines[$found_index]="$merged_line"
        continue
      fi
    fi

    [[ -z "${live_line// /}" ]] && continue
    return 1
  done < "$live_file"

  printf '%s\n' "${output_lines[@]}" > "$proposal_file"
}

sync_live_specs_into_proposal() {
  local repo_root="$1"
  local proposal_dir="$2"
  local live_specs_dir="$repo_root/specs"
  local proposal_specs_dir="$proposal_dir/specs"
  local baseline_specs_dir="$proposal_dir/.pull-base/specs"

  [[ -d "$live_specs_dir" ]] || return 0

  while IFS= read -r live_file; do
    [[ -n "$live_file" ]] || continue
    local rel_path="${live_file#"$live_specs_dir"/}"
    local proposal_file="$proposal_specs_dir/$rel_path"
    local baseline_file="$baseline_specs_dir/$rel_path"

    mkdir -p "$(dirname "$proposal_file")" "$(dirname "$baseline_file")"

    if [[ ! -f "$proposal_file" ]]; then
      cp "$live_file" "$proposal_file"
      cp "$live_file" "$baseline_file"
      continue
    fi

    if cmp -s "$proposal_file" "$live_file"; then
      cp "$live_file" "$baseline_file"
      continue
    fi

    local baseline_source=""
    local head_temp=""
    if [[ -f "$baseline_file" ]]; then
      baseline_source="$baseline_file"
    else
      head_temp="$(mktemp)"
      if git -C "$repo_root" rev-parse --verify --quiet "HEAD:specs/$rel_path" >/dev/null 2>&1 && git -C "$repo_root" show "HEAD:specs/$rel_path" > "$head_temp" 2>/dev/null; then
        baseline_source="$head_temp"
      else
        rm -f "$head_temp"
        head_temp=""
      fi
    fi

    if [[ -z "$baseline_source" ]]; then
      if bootstrap_merge_markdown_file "$proposal_file" "$live_file"; then
        cp "$live_file" "$baseline_file"
        continue
      fi

      echo "Spec merge baseline missing for specs/$rel_path. Commit the live specs file or create a new proposal from the current specs state before running ss-pull." >&2
      return 1
    fi

    if cmp -s "$proposal_file" "$baseline_source"; then
      cp "$live_file" "$proposal_file"
      cp "$live_file" "$baseline_file"
      rm -f "$head_temp"
      continue
    fi

    if cmp -s "$live_file" "$baseline_source"; then
      cp "$live_file" "$baseline_file"
      rm -f "$head_temp"
      continue
    fi

    local current_temp
    local base_temp
    local incoming_temp
    local merged_temp
    current_temp="$(mktemp)"
    base_temp="$(mktemp)"
    incoming_temp="$(mktemp)"
    merged_temp="$(mktemp)"
    cp "$proposal_file" "$current_temp"
    cp "$baseline_source" "$base_temp"
    cp "$live_file" "$incoming_temp"

    if git -C "$repo_root" merge-file -p -- "$current_temp" "$base_temp" "$incoming_temp" > "$merged_temp" 2>/dev/null; then
      cp "$merged_temp" "$proposal_file"
      cp "$live_file" "$baseline_file"
      rm -f "$head_temp" "$current_temp" "$base_temp" "$incoming_temp" "$merged_temp"
      continue
    fi

    local merge_rc=$?
    rm -f "$head_temp" "$current_temp" "$base_temp" "$incoming_temp" "$merged_temp"
    if [[ $merge_rc -eq 1 ]]; then
      echo "Spec merge conflict during ss-pull: specs/$rel_path" >&2
      return 1
    fi

    echo "git merge-file failed with exit code $merge_rc while merging specs/$rel_path" >&2
    return 1
  done < <(find "$live_specs_dir" -type f | LC_ALL=C sort)
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../../../.." && pwd)"
proposes_dir="$repo_root/proposes"
specsync_dir="$repo_root/.specsync"
sessions_dir="$specsync_dir/sessions"
session_id="$(get_session_id "${2:-}")"
session_file="$sessions_dir/$session_id.json"
source_roots_file="$repo_root/.specsync/source-roots.txt"

mkdir -p "$specsync_dir" "$sessions_dir"

proposal_input="${1:-}"
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

  if [[ "$proposal_dir" == "$repo_root/"* ]]; then
    proposal_path="${proposal_dir#"$repo_root"/}"
  else
    proposal_path="$proposal_dir"
  fi
  write_session_binding "$session_file" "$session_id" "$(basename "$proposal_dir")" "$proposal_path" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
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

sync_live_specs_into_proposal "$repo_root" "$proposal_dir"

manifest_path="$proposal_dir/source-state.txt"
mapfile -t source_roots < <(
  if [[ -f "$source_roots_file" ]]; then
    awk 'NF { print $0 }' "$source_roots_file"
  else
    printf 'src\n'
  fi
)

manifest_args=()
for source_root in "${source_roots[@]}"; do
  proposal_root_dir="$(proposal_source_dir "$proposal_dir" "$source_root")"
  if [[ -f "$manifest_path" ]]; then
    proposal_lines="$(root_state_lines "$source_root" "$proposal_root_dir")"
    baseline_lines="$(manifest_root_lines "$manifest_path" "$source_root")"
    if [[ -n "$baseline_lines" && "$proposal_lines" != "$baseline_lines" ]]; then
      echo "Proposal source root contains staged edits that would be overwritten by ss-pull: $source_root" >&2
      exit 1
    fi
    if [[ -z "$baseline_lines" && -d "$proposal_root_dir" ]]; then
      echo "Proposal source root contains content without a captured live baseline: $source_root" >&2
      exit 1
    fi
  elif [[ -d "$proposal_root_dir" ]]; then
    echo "Proposal source root already exists without a captured live baseline. Clear it or create a new proposal before ss-pull: $source_root" >&2
    exit 1
  fi

  if [[ "$source_root" = /* ]] || [[ "$source_root" =~ ^[A-Za-z]:[\\/].* ]]; then
    live_root_dir="$source_root"
  else
    live_root_dir="$repo_root/$source_root"
  fi

  replace_directory "$live_root_dir" "$proposal_root_dir"
  manifest_args+=("$source_root" "$live_root_dir")
done

write_source_state_manifest "$proposal_dir" "${manifest_args[@]}"
printf '%s\n' "$proposal_dir"
