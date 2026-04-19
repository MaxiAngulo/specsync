#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../../../.." && pwd)"
templates_dir="$repo_root/.specsync/templantes"
specs_dir="$repo_root/specs"
proposals_dir="$repo_root/proposes"
archive_dir="$repo_root/proposals-archive"
specsync_dir="$repo_root/.specsync"
sessions_dir="$specsync_dir/sessions"
source_roots_file="$specsync_dir/source-roots.txt"

mkdir -p "$specs_dir" "$proposals_dir" "$archive_dir" "$specsync_dir" "$sessions_dir"

while IFS= read -r -d '' file; do
  rel_path="${file#"$templates_dir"/}"
  dest="$specs_dir/$rel_path"
  mkdir -p "$(dirname "$dest")"
  if [[ ! -e "$dest" ]]; then
    cp "$file" "$dest"
  fi
done < <(find "$templates_dir" -type f -print0)

if [[ ! -e "$source_roots_file" ]]; then
  printf 'src\n' > "$source_roots_file"
  # Auto-detect common test-code root folders and add them when present
  for test_dir in test tests; do
    if [[ -d "$repo_root/$test_dir" ]]; then
      printf '%s\n' "$test_dir" >> "$source_roots_file"
    fi
  done
fi

printf '%s\n' "$repo_root"
