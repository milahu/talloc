#!/usr/bin/env bash

set -eux

src_url='https://www.samba.org/ftp/talloc/'

export GIT_AUTHOR_NAME=samba
export GIT_AUTHOR_EMAIL=

export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"

src_html="$(curl "$src_url")"

git checkout master

last_version=$(git log --format=%B -n1)
if ! echo "$last_version" | grep -q -E '[0-9.]+'; then
  echo "error: unexpected last_version: $last_version"
  exit 1
fi

echo "last_version: $last_version"

function max_version() {
  printf "%s\n%s\n" "$1" "$2" | sort --version-sort -r | head -n1
}

echo "$src_html" |
grep -E 'href="talloc-[0-9.]+.tar.gz"' |
while read -r line; do
  #echo "line: $line" >&2
  file="$(echo "$line" | grep -o -E -m1 'talloc-[0-9.]+.tar.gz' | head -n1)"
  time="$(echo "$line" | sed -E 's|^.*<td class="indexcollastmod">([0-9-]+ [0-9:]+)  </td>.*$|\1|')"
  version=${file%.tar.gz}; version=${version#talloc-}
  cmp_version="$(printf "%s\n%s\n" "$version" "$last_version" | sort --version-sort -r | head -n1)"
  #echo "version=$version cmp_version=$cmp_version" >&2
  if [ "$(max_version "$version" "$last_version")" = "$last_version" ]; then continue; fi
  echo "$version $time"
done |
sort --version-sort |
while read version time; do
  echo "version=$version time=$time"
  file="talloc-$version.tar.gz"
  url="$src_url/$file"
  git rm -rf . || true
  wget "$url"
  tar --strip-components=1 -x -f "$file"
  rm "$file"
  git add .
  export GIT_AUTHOR_DATE="$time"
  export GIT_COMMITTER_DATE="$GIT_AUTHOR_DATE"
  git commit -m "$version"
  git tag "$version"
done
