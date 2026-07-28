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
# 2단계: gh / glab 으로 실제 머지된 PR·MR 조회
# ─────────────────────────────────────────────────────────────

# detect_from_forge: GitHub 리모트에서 머지된 PR 의 base 브랜치를 반환한다
@test "detect_from_forge returns the base branch of a merged GitHub PR" {
    use_github_remote
    stub_gh "printf 'develop\n'"

    run detect_from_forge "feature-x"
    [ "$status" -eq 0 ]
    [ "$output" = "develop" ]
}

# detect_from_forge: gh 호출 시 머지된 PR 만 조회한다
@test "detect_from_forge queries only merged PRs" {
    use_github_remote
    stub_gh "printf 'develop\n'"

    detect_from_forge "feature-x"

    [[ "$(gh_args)" == *"--state merged"* ]]
    [[ "$(gh_args)" == *"--head feature-x"* ]]
}

# detect_from_forge: 머지된 PR 이 없으면 실패한다
@test "detect_from_forge fails when no merged PR exists" {
    use_github_remote
    stub_gh "printf '\n'"

    run detect_from_forge "feature-x"
    [ "$status" -ne 0 ]
}

# detect_from_forge: gh 가 null 을 반환하면 실패한다
@test "detect_from_forge fails when gh returns null" {
    use_github_remote
    stub_gh "printf 'null\n'"

    run detect_from_forge "feature-x"
    [ "$status" -ne 0 ]
}

# detect_from_forge: gh 인증 실패 시 실패한다
@test "detect_from_forge fails when gh is unauthenticated" {
    use_github_remote
    stub_gh "exit 1"

    run detect_from_forge "feature-x"
    [ "$status" -ne 0 ]
}

# detect_from_forge: GitLab 리모트에서 머지된 MR 의 target_branch 를 반환한다
@test "detect_from_forge returns the target_branch of a merged GitLab MR" {
    use_gitlab_remote
    stub_glab "printf '%s\n' '[{\"target_branch\":\"develop\",\"title\":\"x\"}]'"

    run detect_from_forge "feature-x"
    [ "$status" -eq 0 ]
    [ "$output" = "develop" ]
}

# detect_from_forge: glab 호출 시 머지된 MR 만 조회한다
@test "detect_from_forge queries only merged MRs" {
    use_gitlab_remote
    stub_glab "printf '%s\n' '[{\"target_branch\":\"develop\"}]'"

    detect_from_forge "feature-x"

    [[ "$(glab_args)" == *"--merged"* ]]
    [[ "$(glab_args)" == *"--source-branch feature-x"* ]]
}

# detect_from_forge: 빈 MR 목록이면 실패한다
@test "detect_from_forge fails on an empty MR list" {
    use_gitlab_remote
    stub_glab "printf '%s\n' '[]'"

    run detect_from_forge "feature-x"
    [ "$status" -ne 0 ]
}

# detect_from_forge: GitHub/GitLab 이 아닌 리모트면 실패한다
@test "detect_from_forge fails on a non GitHub or GitLab remote" {
    stub_gh "printf 'develop\n'"

    run detect_from_forge "feature-x"
    [ "$status" -ne 0 ]
}

# detect_from_forge: gh 가 설치되어 있지 않으면 실행을 시도하지 않고 실패한다
@test "detect_from_forge fails when gh is not installed at all" {
    use_github_remote
    remove_forge_cli || skip "축소한 PATH 에도 gh/glab 이 존재하는 환경"

    run detect_from_forge "feature-x"
    [ "$status" -ne 0 ]
}

# detect_from_forge: glab 이 설치되어 있지 않으면 실행을 시도하지 않고 실패한다
@test "detect_from_forge fails when glab is not installed at all" {
    use_gitlab_remote
    remove_forge_cli || skip "축소한 PATH 에도 gh/glab 이 존재하는 환경"

    run detect_from_forge "feature-x"
    [ "$status" -ne 0 ]
}

# ─────────────────────────────────────────────────────────────
# glab JSON 파싱 (jq 경로 / sed 폴백 경로)
# ─────────────────────────────────────────────────────────────

@test "extract_target_branch_jq reads the first target_branch" {
    run extract_target_branch_jq '[{"target_branch":"develop","title":"x"}]'
    [ "$status" -eq 0 ]
    [ "$output" = "develop" ]
}

@test "extract_target_branch_jq fails on an empty list" {
    run extract_target_branch_jq '[]'
    [ "$status" -ne 0 ]
}

# jq 가 없는 환경에서 쓰이는 폴백. 항목이 여럿이어도 첫 번째를 골라야 한다.
@test "extract_target_branch_sed reads the first target_branch" {
    run extract_target_branch_sed '[{"target_branch":"develop","title":"x"}]'
    [ "$status" -eq 0 ]
    [ "$output" = "develop" ]
}

@test "extract_target_branch_sed picks the first entry when several are returned" {
    run extract_target_branch_sed '[{"target_branch":"develop"},{"target_branch":"main"}]'
    [ "$status" -eq 0 ]
    [ "$output" = "develop" ]
}

@test "extract_target_branch_sed fails on an empty list" {
    run extract_target_branch_sed '[]'
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
    stub_gh "printf 'develop\n'"

    resolve_target_branch "feature-x"
    [ "$TARGET_BRANCH" = "release/2026-H1" ]
    [ -z "$(gh_args)" ]
}

# resolve_target_branch: config 가 없으면 gh 결과를 쓴다
@test "resolve_target_branch uses the gh result when config is unset" {
    use_github_remote
    stub_gh "printf 'develop\n'"

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
