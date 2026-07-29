#!/usr/bin/env bats
#
# 타겟 브랜치 자동 감지 체인 단위 테스트

setup() {
    load "helpers/common"
    setup_repo
    load_lib
}

teardown() {
    teardown_repo
}

# ─────────────────────────────────────────────────────────────
# 1단계: git config pr-done.target
# ─────────────────────────────────────────────────────────────

# detect_from_config: 설정된 값을 반환한다
@test "detect_from_config returns the configured value" {
    git config pr-done.target "develop"

    run detect_from_config
    [ "$status" -eq 0 ]
    [ "$output" = "develop" ]
}

# detect_from_config: 설정이 없으면 실패한다
@test "detect_from_config fails when the config is unset" {
    run detect_from_config
    [ "$status" -ne 0 ]
    [ -z "$output" ]
}

# ─────────────────────────────────────────────────────────────
# 호스팅 판별 — GitHub 과 GitLab 이 같은 규칙으로 인식되어야 한다
# ─────────────────────────────────────────────────────────────

expect_forge() {
    git remote set-url origin "$1"
    run forge_kind
    [ "$output" = "$2" ]
}

@test "forge_kind recognises the public hosts" {
    expect_forge "https://github.com/acme/repo.git" "github"
    expect_forge "https://gitlab.com/acme/repo.git" "gitlab"
    expect_forge "git@github.com:acme/repo.git"     "github"
    expect_forge "git@gitlab.com:acme/repo.git"     "gitlab"
}

@test "forge_kind recognises self hosted instances symmetrically" {
    expect_forge "https://github.acme.com/x/y.git" "github"
    expect_forge "https://gitlab.acme.com/x/y.git" "gitlab"
    expect_forge "https://mygithub-host/x/y.git"   "github"
    expect_forge "https://mygitlab-host/x/y.git"   "gitlab"
}

# 저장소 이름에 다른 호스팅 이름이 들어가도 호스트로만 판단해야 한다
@test "forge_kind judges by host, not by repository name" {
    expect_forge "https://gitlab.com/acme/github-tools.git" "gitlab"
    expect_forge "https://github.com/acme/gitlab-runner.git" "github"
    expect_forge "git@gitlab.com:acme/github-tools.git" "gitlab"
}

# 이름으로 알 수 없는 호스트는 설정으로 지정할 수 있다 (두 호스팅 공통 탈출구)
@test "forge_kind honours an explicit pr-done.forge setting" {
    git remote set-url origin "https://ghe.acme.com/x/y.git"
    git config pr-done.forge "github"
    run forge_kind
    [ "$output" = "github" ]

    git config pr-done.forge "gitlab"
    run forge_kind
    [ "$output" = "gitlab" ]
}

@test "forge_kind fails on an unknown host with no setting" {
    git remote set-url origin "https://git.acme.com/x/y.git"
    run forge_kind
    [ "$status" -ne 0 ]
}

# ─────────────────────────────────────────────────────────────
# 2단계: gh / glab 으로 실제 머지된 PR·MR 조회
# ─────────────────────────────────────────────────────────────

# query_forge: GitHub 리모트에서 머지된 PR 의 base 브랜치를 얻는다
@test "query_forge reads the base branch of a merged GitHub PR" {
    use_github_remote
    stub_gh_merged "develop" "abc1234"

    query_forge "feature-x"
    [ "$FORGE_BASE" = "develop" ]
}

# query_forge: 머지 시점의 head 커밋도 함께 기록한다 (증거 대조용)
@test "query_forge records the head commit of the merged PR" {
    use_github_remote
    stub_gh_merged "develop" "abc1234"

    query_forge "feature-x"
    [ "$FORGE_HEAD_OID" = "abc1234" ]
}

# query_forge: 같은 브랜치를 두 번 물어도 실제 조회는 한 번만 한다
@test "query_forge queries the forge only once per branch" {
    use_github_remote
    stub_gh_merged "develop" "abc1234"

    query_forge "feature-x"
    query_forge "feature-x"

    [ "$(gh_args | wc -l | tr -d ' ')" -eq 1 ]
}

# query_forge: 머지된 PR 만, head SHA 와 머지 시각까지 요청한다
@test "query_forge asks only for merged PRs and includes the head SHA" {
    use_github_remote
    stub_gh_merged "develop" "abc1234"

    query_forge "feature-x"

    [[ "$(gh_args)" == *"--state merged"* ]]
    [[ "$(gh_args)" == *"--head feature-x"* ]]
    [[ "$(gh_args)" == *"headRefOid"* ]]
    [[ "$(gh_args)" == *"mergedAt"* ]]
}

# gh 에는 --order 가 없으므로 내장 jq 로 정렬을 시켜야
# 외부 jq 가 없는 환경에서도 GitLab 과 같은 순서를 받는다
@test "query_forge makes gh sort by merge date server side" {
    use_github_remote
    stub_gh_merged "develop" "abc1234"

    query_forge "feature-x"

    [[ "$(gh_args)" == *"sort_by(.mergedAt)"* ]]
}

# 폴백(정렬 불가) 경로도 두 호스팅이 같은 순서를 전제로 동작한다
@test "pick_latest_merge_sed takes the first entry of an already sorted list" {
    run pick_latest_merge_sed '[{"baseRefName":"new","headRefOid":"bbb"},{"baseRefName":"old","headRefOid":"aaa"}]' baseRefName headRefOid mergedAt
    [ "$status" -eq 0 ]
    [ "$output" = "new bbb" ]
}

# 같은 이름으로 여러 번 머지된 경우 GitHub 에서도 가장 최근 머지를 고른다
@test "query_forge picks the most recent merge on GitHub too" {
    use_github_remote
    stub_gh "printf '%s\n' '[{\"baseRefName\":\"old\",\"headRefOid\":\"aaa\",\"mergedAt\":\"2025-01-01T00:00:00Z\"},{\"baseRefName\":\"new\",\"headRefOid\":\"bbb\",\"mergedAt\":\"2026-06-01T00:00:00Z\"}]'"

    query_forge "feature-x"
    [ "$FORGE_BASE" = "new" ]
    [ "$FORGE_HEAD_OID" = "bbb" ]
}

# query_forge: 머지된 PR 이 없으면 실패한다
@test "query_forge fails when no merged PR exists" {
    use_github_remote
    stub_gh "printf '\n'"

    run query_forge "feature-x"
    [ "$status" -ne 0 ]
}

# query_forge: gh 가 빈 배열을 반환하면 실패한다
@test "query_forge fails when gh returns an empty list" {
    use_github_remote
    stub_gh "printf '%s\n' '[]'"

    run query_forge "feature-x"
    [ "$status" -ne 0 ]
}

# query_forge: gh 인증 실패 시 실패한다
@test "query_forge fails when gh is unauthenticated" {
    use_github_remote
    stub_gh "exit 1"

    run query_forge "feature-x"
    [ "$status" -ne 0 ]
}

# query_forge: GitLab 리모트에서 target_branch 와 sha 를 얻는다
@test "query_forge reads target_branch and sha of a merged GitLab MR" {
    use_gitlab_remote
    stub_glab_merged "develop" "def5678"

    query_forge "feature-x"
    [ "$FORGE_BASE" = "develop" ]
    [ "$FORGE_HEAD_OID" = "def5678" ]
}

# query_forge: glab 호출 시 머지된 MR 만 조회한다
@test "query_forge asks only for merged MRs" {
    use_gitlab_remote
    stub_glab_merged "develop" "def5678"

    query_forge "feature-x"

    [[ "$(glab_args)" == *"--merged"* ]]
    [[ "$(glab_args)" == *"--source-branch feature-x"* ]]
}

# query_forge: 빈 MR 목록이면 실패한다
@test "query_forge fails on an empty MR list" {
    use_gitlab_remote
    stub_glab "printf '%s\n' '[]'"

    run query_forge "feature-x"
    [ "$status" -ne 0 ]
}

# query_forge: GitHub/GitLab 이 아닌 리모트면 실패한다
@test "query_forge fails on a non GitHub or GitLab remote" {
    stub_gh_merged "develop" "abc1234"

    run query_forge "feature-x"
    [ "$status" -ne 0 ]
}

# query_forge: gh 가 설치되어 있지 않으면 실행을 시도하지 않고 실패한다
@test "query_forge fails when gh is not installed at all" {
    use_github_remote
    remove_forge_cli || skip "축소한 PATH 에도 gh/glab 이 존재하는 환경"

    run query_forge "feature-x"
    [ "$status" -ne 0 ]
}

# query_forge: glab 이 설치되어 있지 않으면 실행을 시도하지 않고 실패한다
@test "query_forge fails when glab is not installed at all" {
    use_gitlab_remote
    remove_forge_cli || skip "축소한 PATH 에도 gh/glab 이 존재하는 환경"

    run query_forge "feature-x"
    [ "$status" -ne 0 ]
}

# ─────────────────────────────────────────────────────────────
# 머지 목록 파싱 — GitHub 과 GitLab 이 같은 함수를 통과한다
# 키 이름만 다르고 (baseRefName/headRefOid/mergedAt vs
# target_branch/sha/merged_at) 선택 규칙은 동일해야 한다
# ─────────────────────────────────────────────────────────────

GH_KEYS="baseRefName headRefOid mergedAt"
GL_KEYS="target_branch sha merged_at"

@test "pick_latest_merge reads a single GitHub entry" {
    run pick_latest_merge '[{"baseRefName":"develop","headRefOid":"abc123","mergedAt":"2026-01-01T00:00:00Z"}]' $GH_KEYS
    [ "$status" -eq 0 ]
    [ "$output" = "develop abc123" ]
}

@test "pick_latest_merge reads a single GitLab entry" {
    run pick_latest_merge '[{"target_branch":"develop","sha":"abc123","merged_at":"2026-01-01T00:00:00Z"}]' $GL_KEYS
    [ "$status" -eq 0 ]
    [ "$output" = "develop abc123" ]
}

# 같은 브랜치 이름으로 여러 번 머지된 경우, 두 호스팅 모두 가장 최근 머지를 골라야 한다
@test "pick_latest_merge picks the most recent merge on GitHub" {
    run pick_latest_merge '[{"baseRefName":"old","headRefOid":"aaa","mergedAt":"2025-01-01T00:00:00Z"},{"baseRefName":"new","headRefOid":"bbb","mergedAt":"2026-06-01T00:00:00Z"}]' $GH_KEYS
    [ "$status" -eq 0 ]
    [ "$output" = "new bbb" ]
}

@test "pick_latest_merge picks the most recent merge on GitLab" {
    run pick_latest_merge '[{"target_branch":"old","sha":"aaa","merged_at":"2025-01-01T00:00:00Z"},{"target_branch":"new","sha":"bbb","merged_at":"2026-06-01T00:00:00Z"}]' $GL_KEYS
    [ "$status" -eq 0 ]
    [ "$output" = "new bbb" ]
}

# 입력 순서와 무관하게 같은 답이 나와야 한다
@test "pick_latest_merge ignores the order the forge returned" {
    run pick_latest_merge '[{"baseRefName":"new","headRefOid":"bbb","mergedAt":"2026-06-01T00:00:00Z"},{"baseRefName":"old","headRefOid":"aaa","mergedAt":"2025-01-01T00:00:00Z"}]' $GH_KEYS
    [ "$status" -eq 0 ]
    [ "$output" = "new bbb" ]
}

# 아직 머지되지 않은 항목은 후보에서 뺀다
@test "pick_latest_merge skips entries that were never merged" {
    run pick_latest_merge '[{"baseRefName":"open","headRefOid":"aaa","mergedAt":null},{"baseRefName":"done","headRefOid":"bbb","mergedAt":"2026-06-01T00:00:00Z"}]' $GH_KEYS
    [ "$status" -eq 0 ]
    [ "$output" = "done bbb" ]
}

@test "pick_latest_merge fails on an empty GitHub list" {
    run pick_latest_merge '[]' $GH_KEYS
    [ "$status" -ne 0 ]
}

@test "pick_latest_merge fails on an empty GitLab list" {
    run pick_latest_merge '[]' $GL_KEYS
    [ "$status" -ne 0 ]
}

# jq 가 없는 환경용 폴백. 정렬은 못 하지만 두 호스팅에 똑같이 적용된다
@test "pick_latest_merge_sed reads a GitHub entry" {
    run pick_latest_merge_sed '[{"baseRefName":"develop","headRefOid":"abc123"}]' $GH_KEYS
    [ "$status" -eq 0 ]
    [ "$output" = "develop abc123" ]
}

@test "pick_latest_merge_sed reads a GitLab entry" {
    run pick_latest_merge_sed '[{"target_branch":"develop","sha":"abc123"}]' $GL_KEYS
    [ "$status" -eq 0 ]
    [ "$output" = "develop abc123" ]
}

@test "pick_latest_merge_sed fails on an empty list" {
    run pick_latest_merge_sed '[]' $GH_KEYS
    [ "$status" -ne 0 ]
}

# ─────────────────────────────────────────────────────────────
# 머지 증거: PR head 커밋과 현재 브랜치 끝의 대조
# ─────────────────────────────────────────────────────────────

# 브랜치 끝이 PR head 와 같으면 증거로 인정한다
@test "forge_head_matches accepts an exact head match" {
    make_branch "feature-x"
    FORGE_HEAD_OID=$(git rev-parse "feature-x")

    run forge_head_matches "feature-x"
    [ "$status" -eq 0 ]
}

# 브랜치 끝이 PR head 의 조상이면 인정한다 (내 커밋은 전부 머지된 상태)
@test "forge_head_matches accepts when the branch tip is an ancestor" {
    make_branch "feature-x"
    make_branch "feature-x-ahead" "feature-x"
    FORGE_HEAD_OID=$(git rev-parse "feature-x-ahead")

    run forge_head_matches "feature-x"
    [ "$status" -eq 0 ]
}

# PR 머지 이후 새 커밋을 쌓았으면 증거가 아니다
@test "forge_head_matches rejects commits added after the merge" {
    make_branch "feature-x"
    FORGE_HEAD_OID=$(git rev-parse "feature-x")
    git checkout --quiet "feature-x"
    echo "머지 이후 새 작업" >> file.txt
    git commit --quiet -am "머지 뒤에 추가한 커밋"

    run forge_head_matches "feature-x"
    [ "$status" -ne 0 ]
}

# 이름만 같은 과거 PR (전혀 다른 커밋) 은 증거가 아니다
@test "forge_head_matches rejects an unrelated commit from a reused branch name" {
    make_branch "feature-x"
    FORGE_HEAD_OID="0000000000000000000000000000000000000000"

    run forge_head_matches "feature-x"
    [ "$status" -ne 0 ]
}

# SHA 를 얻지 못했으면 증거로 인정하지 않는다 (fail-closed)
@test "forge_head_matches rejects when no head SHA was obtained" {
    make_branch "feature-x"
    FORGE_HEAD_OID=""

    run forge_head_matches "feature-x"
    [ "$status" -ne 0 ]
}

# ─────────────────────────────────────────────────────────────
# 3단계: git branch -r --contains 로 추론
# ─────────────────────────────────────────────────────────────

# detect_from_contains: 머지된 원격 브랜치가 하나면 그 브랜치를 반환한다
@test "detect_from_contains returns the single remote branch holding the merge" {
    make_branch "develop"
    make_branch "feature-x" "develop"
    merge_branch "feature-x" "develop"
    push_all

    run detect_from_contains "feature-x"
    [ "$status" -eq 0 ]
    [ "$output" = "develop" ]
}

# detect_from_contains: 후보가 여럿이면 가장 먼저 머지된 브랜치를 고른다
@test "detect_from_contains picks the earliest merge target among candidates" {
    make_branch "develop"
    make_branch "feature-x" "develop"
    merge_branch "feature-x" "develop"
    merge_branch "develop" "main"
    push_all

    run detect_from_contains "feature-x"
    [ "$status" -eq 0 ]
    [ "$output" = "develop" ]
}

# detect_from_contains: 아직 머지되지 않았으면 실패한다
@test "detect_from_contains fails when the branch is not merged yet" {
    make_branch "develop"
    make_branch "feature-x" "develop"
    push_all

    run detect_from_contains "feature-x"
    [ "$status" -ne 0 ]
}

# detect_from_contains: 로컬에 없는 브랜치는 후보에서 제외한다
@test "detect_from_contains skips candidates missing from local" {
    make_branch "develop"
    make_branch "feature-x" "develop"
    merge_branch "feature-x" "develop"
    push_all
    git branch --quiet -D develop

    run detect_from_contains "feature-x"
    [ "$status" -ne 0 ]
}

# ─────────────────────────────────────────────────────────────
# 4단계: origin/HEAD
# ─────────────────────────────────────────────────────────────

# detect_from_remote_head: 그 브랜치에 머지된 흔적이 있을 때만 반환한다
@test "detect_from_remote_head returns origin HEAD when the branch is merged into it" {
    make_branch "feature-x"
    merge_branch "feature-x" "main"
    push_all
    set_remote_head "main"

    run detect_from_remote_head "feature-x"
    [ "$status" -eq 0 ]
    [ "$output" = "main" ]
}

# detect_from_remote_head: origin/HEAD 는 "저장소 기본 브랜치"일 뿐이므로
# 머지 흔적이 없으면 채택하지 않는다 (엉뚱한 브랜치로 이동 방지)
@test "detect_from_remote_head refuses origin HEAD without merge evidence" {
    make_branch "feature-x"
    push_all
    set_remote_head "main"

    run detect_from_remote_head "feature-x"
    [ "$status" -ne 0 ]
}

# detect_from_remote_head: origin/HEAD 가 없으면 실패한다
@test "detect_from_remote_head fails when origin HEAD is unset" {
    run detect_from_remote_head "feature-x"
    [ "$status" -ne 0 ]
}

# ─────────────────────────────────────────────────────────────
# 감지 체인 통합
# ─────────────────────────────────────────────────────────────

# resolve_target_branch: config 를 gh 보다 우선한다
@test "resolve_target_branch prefers config over gh" {
    use_github_remote
    git config pr-done.target "release/2026-H1"
    stub_gh_merged "develop" "abc1234"

    resolve_target_branch "feature-x"
    [ "$TARGET_BRANCH" = "release/2026-H1" ]
    [ -z "$(gh_args)" ]
}

# resolve_target_branch: config 가 없으면 gh 결과를 쓴다
@test "resolve_target_branch uses the gh result when config is unset" {
    use_github_remote
    stub_gh_merged "develop" "abc1234"

    resolve_target_branch "feature-x"
    [ "$TARGET_BRANCH" = "develop" ]
}

# resolve_target_branch: gh 를 못 쓰면 git 추론으로 넘어간다
@test "resolve_target_branch falls back to git inference without gh" {
    make_branch "develop"
    make_branch "feature-x" "develop"
    merge_branch "feature-x" "develop"
    push_all
    hide_forge_cli

    resolve_target_branch "feature-x"
    [ "$TARGET_BRANCH" = "develop" ]
}

# resolve_target_branch: git 추론도 실패하면 origin/HEAD 로 넘어간다
# (origin/HEAD 도 머지 흔적이 있을 때만 채택된다)
@test "resolve_target_branch falls back to origin HEAD" {
    make_branch "feature-x"
    merge_branch "feature-x" "main"
    push_all
    set_remote_head "main"
    git checkout --quiet feature-x
    git branch --quiet -D main        # 로컬 main 을 없애 3단계 후보에서 제외시킨다
    hide_forge_cli

    resolve_target_branch "feature-x"
    [ "$TARGET_BRANCH" = "main" ]
}

# resolve_target_branch: 모든 경로가 실패하면 0 이 아닌 상태로 끝난다
@test "resolve_target_branch fails when every path fails" {
    hide_forge_cli

    run resolve_target_branch "feature-x"
    [ "$status" -ne 0 ]
}

# resolve_target_branch: 감지 출처를 TARGET_SOURCE 에 기록한다
@test "resolve_target_branch records the detection source" {
    git config pr-done.target "develop"

    resolve_target_branch "feature-x"
    [ -n "$TARGET_SOURCE" ]
    [[ "$TARGET_SOURCE" == *"pr-done.target"* ]]
}
