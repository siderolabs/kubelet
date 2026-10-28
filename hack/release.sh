#!/usr/bin/env bash
#
# Release a new kubelet version.
#
# Usage: hack/release.sh vX.Y.Z
#
# Requirements: gh (authenticated, or GITHUB_TOKEN in the environment), git.
#
# It patches the Makefile with the new KUBELET_VER, commits the change to main
# with a DCO sign-off, pushes, tags the release, waits for the tag's GitHub
# Actions run to succeed, and then signs the images.

set -euo pipefail

if [[ $# -ne 1 ]]; then
	echo "usage: $0 vX.Y.Z" >&2
	exit 1
fi

TAG="$1"

if [[ ! "${TAG}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-.+)?$ ]]; then
	echo "error: tag must look like vX.Y.Z (got '${TAG}')" >&2
	exit 1
fi

cd "$(git rev-parse --show-toplevel)"

# Staged changes are fine (they are left staged and not included in the
# release commit), but unstaged or untracked changes are not.
if git status --porcelain | grep -q '^.[^ ]'; then
	echo "error: working tree is not clean; commit, stage or stash changes first" >&2
	git status --short >&2
	exit 1
fi

if ! git diff --cached --quiet -- Makefile; then
	echo "error: Makefile has staged changes; unstage them first" >&2
	exit 1
fi

# Fail early (before pushing anything) if gh can't talk to GitHub, e.g. an
# expired GITHUB_TOKEN.
if ! gh auth status >/dev/null 2>&1; then
	echo "error: gh is not authenticated; check GITHUB_TOKEN or run 'gh auth login'" >&2
	gh auth status >&2 || true
	exit 1
fi

CURRENT_VER="$(sed -n 's/^KUBELET_VER := //p' Makefile)"
echo "current version: ${CURRENT_VER}"
echo "new version:     ${TAG}"

if [[ "${CURRENT_VER}" == "${TAG}" ]]; then
	echo "error: Makefile already set to ${TAG}" >&2
	exit 1
fi

# Patch the Makefile.
sed -i.bak "s|^KUBELET_VER := .*|KUBELET_VER := ${TAG}|" Makefile
rm -f Makefile.bak

# Commit to main with DCO sign-off.
git commit --signoff \
	-m "feat: update kubelet to ${TAG}" \
	-m "See https://github.com/kubernetes/kubernetes/releases/tag/${TAG}"

git push origin HEAD

# Tag the release and push it.
git tag "${TAG}" -m "${TAG}"
git push origin "${TAG}"

# Wait for the GitHub Actions run for this tag to complete.
echo "waiting for the GitHub Actions run for ${TAG} to start..."
RUN_ID=""
for _ in $(seq 1 30); do
	RUN_ID="$(gh run list --branch "${TAG}" --limit 1 --json databaseId --jq '.[0].databaseId // empty')"
	if [[ -n "${RUN_ID}" ]]; then
		break
	fi
	sleep 5
done

if [[ -z "${RUN_ID}" ]]; then
	echo "error: could not find a workflow run for ${TAG}" >&2
	exit 1
fi

echo "watching run ${RUN_ID}..."
gh run watch "${RUN_ID}" --exit-status

# Sign the images now that the tagged build succeeded.
make sign-images
