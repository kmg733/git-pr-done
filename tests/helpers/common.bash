#!/usr/bin/env bash
#
# 테스트 공통 헬퍼
#
# 각 테스트는 임시 git 저장소와 임시 PATH(스텁 바이너리용)에서 격리 실행된다.
# 실제 네트워크나 실제 gh/glab 은 절대 호출하지 않는다.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GIT_PR_DONE="$PROJECT_ROOT/git-pr-done"

# git-pr-done 의 함수만 로드한다 (인자 파싱/메인 실행 흐름은 건너뜀).
load_lib() {
    # shellcheck source=/dev/null
    GIT_PR_DONE_LIB_ONLY=1 source "$GIT_PR_DONE"
}

# origin 리모트가 연결된 임시 저장소를 만들고 그 안으로 이동한다.
# main 브랜치에 커밋 1개가 있는 상태로 시작한다.
setup_repo() {
    TEST_TMP="$(mktemp -d)"
    STUB_BIN="$TEST_TMP/bin"
    mkdir -p "$STUB_BIN"
    PATH="$STUB_BIN:$PATH"
    export PATH

    # 임시 클론에서도 커밋할 수 있도록 신원을 환경변수로 둔다
    export GIT_AUTHOR_NAME="tester" GIT_AUTHOR_EMAIL="tester@example.com"
    export GIT_COMMITTER_NAME="tester" GIT_COMMITTER_EMAIL="tester@example.com"

    git init --quiet --bare "$TEST_TMP/origin.git"
    git init --quiet -b main "$TEST_TMP/work"
    cd "$TEST_TMP/work" || return 1
    git config user.email "tester@example.com"
    git config user.name "tester"
    git config commit.gpgsign false

    echo "init" > file.txt
    git add file.txt
    git commit --quiet -m "init"
    git remote add origin "$TEST_TMP/origin.git"
    git push --quiet -u origin main
}

teardown_repo() {
    cd / || true
    if [[ -n "${TEST_TMP:-}" && -d "$TEST_TMP" ]]; then
        rm -rf "$TEST_TMP"
    fi
}

# 브랜치를 만들고 커밋 1개를 추가한 뒤 원본 브랜치로 돌아온다.
make_branch() {
    local name="$1" from="${2:-main}" prev
    prev=$(git symbolic-ref --short HEAD)
    git checkout --quiet -b "$name" "$from"
    echo "$name" >> file.txt
    git commit --quiet -am "work on $name"
    git checkout --quiet "$prev"
}

# from 브랜치를 into 브랜치에 머지 커밋으로 병합한다.
merge_branch() {
    local from="$1" into="$2" prev
    prev=$(git symbolic-ref --short HEAD)
    git checkout --quiet "$into"
    git merge --quiet --no-ff -m "merge $from into $into" "$from"
    git checkout --quiet "$prev"
}

# 모든 로컬 브랜치를 origin 에 푸시하고 upstream 을 설정한다.
# (upstream 이 없으면 실제 실행 테스트에서 git pull --ff-only 가 실패한다)
push_all() {
    git push --quiet --set-upstream origin --all
}

# 서버 쪽(다른 클론)에서 머지한다. 웹 UI 머지 시뮬레이션.
# 로컬 저장소의 원격 추적 참조는 갱신되지 않은 채로 남는다.
merge_on_server() {
    local from="$1" into="$2" clone="$TEST_TMP/server-clone"
    rm -rf "$clone"
    git clone --quiet "$TEST_TMP/origin.git" "$clone"
    git -C "$clone" checkout --quiet "$into"
    git -C "$clone" merge --quiet --no-ff -m "merge $from into $into" "origin/$from"
    git -C "$clone" push --quiet origin "$into"
    rm -rf "$clone"
}

# origin/HEAD 를 지정 브랜치로 설정한다.
set_remote_head() {
    git symbolic-ref "refs/remotes/origin/HEAD" "refs/remotes/origin/$1"
}

# origin 리모트를 특정 호스팅으로 인식시킨다.
#
# 실제 호스팅 URL 을 넣으면 forge_kind 는 속일 수 있지만 fetch/push 가 네트워크로
# 나가 실패한다. 그래서 호스팅 이름이 들어간 로컬 경로로 bare 저장소를 가리키게 해
# forge 판별과 git 동작을 동시에 성립시킨다.
use_forge_remote() {
    local host="$1" dir="$TEST_TMP/$1"
    mkdir -p "$dir"
    [[ -e "$dir/demo.git" ]] || ln -s "$TEST_TMP/origin.git" "$dir/demo.git"
    git remote set-url origin "$dir/demo.git"
}

use_github_remote() {
    use_forge_remote "github.com"
}

use_gitlab_remote() {
    use_forge_remote "gitlab.com"
}

# gh 스텁 설치. 인자를 로그에 남기고 전달받은 본문을 실행한다.
stub_gh() {
    local body="$1"
    cat > "$STUB_BIN/gh" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$TEST_TMP/gh-args.log"
$body
STUB
    chmod +x "$STUB_BIN/gh"
}

# 머지된 PR 이 있는 gh 스텁. gh 는 JSON 배열을 그대로 내보낸다.
#   stub_gh_merged <base> <sha> [mergedAt]
stub_gh_merged() {
    local at="${3:-2026-01-01T00:00:00Z}"
    stub_gh "printf '%s\n' '[{\"baseRefName\":\"$1\",\"headRefOid\":\"$2\",\"mergedAt\":\"$at\"}]'"
}

# 머지된 MR 이 있는 glab 스텁. glab 도 JSON 배열을 그대로 내보낸다.
#   stub_glab_merged <base> <sha> [merged_at]
stub_glab_merged() {
    local at="${3:-2026-01-01T00:00:00Z}"
    stub_glab "printf '%s\n' '[{\"target_branch\":\"$1\",\"sha\":\"$2\",\"merged_at\":\"$at\",\"title\":\"x\"}]'"
}

# glab 스텁 설치.
stub_glab() {
    local body="$1"
    cat > "$STUB_BIN/glab" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$TEST_TMP/glab-args.log"
$body
STUB
    chmod +x "$STUB_BIN/glab"
}

# gh/glab 이 설치는 됐지만 실패하는 상황 (미인증, API 오류 등).
# command -v 는 성공하고 실행만 실패한다.
hide_forge_cli() {
    cat > "$STUB_BIN/gh" <<'STUB'
#!/usr/bin/env bash
exit 1
STUB
    cat > "$STUB_BIN/glab" <<'STUB'
#!/usr/bin/env bash
exit 1
STUB
    chmod +x "$STUB_BIN/gh" "$STUB_BIN/glab"
}

# gh/glab 이 아예 설치되지 않은 상황.
# PATH 를 축소해 command -v 자체가 실패하게 만든다.
# 축소해도 CLI 가 남아 있는 환경에서는 호출한 테스트가 skip 되도록 0 이 아닌 값을 반환한다.
remove_forge_cli() {
    rm -f "$STUB_BIN/gh" "$STUB_BIN/glab"
    PATH="$STUB_BIN:/usr/bin:/bin"
    export PATH
    if command -v gh >/dev/null 2>&1 || command -v glab >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

# gh 스텁에 기록된 인자를 반환한다.
gh_args() {
    cat "$TEST_TMP/gh-args.log" 2>/dev/null || true
}

glab_args() {
    cat "$TEST_TMP/glab-args.log" 2>/dev/null || true
}
