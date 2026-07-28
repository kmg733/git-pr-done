#!/usr/bin/env bats
#
# CLI 동작 통합 테스트 (실제 스크립트를 --dry-run 으로 실행)

setup() {
    load "helpers/common"
    setup_repo
}

teardown() {
    teardown_repo
}

# main → develop → feature-x 구조를 만들고 feature-x 를 체크아웃한다.
# feature-x 는 develop 에 머지된 상태다.
setup_merged_feature() {
    make_branch "develop"
    make_branch "feature-x" "develop"
    merge_branch "feature-x" "develop"
    push_all
    git checkout --quiet "feature-x"
}

# --target 을 명시하면 자동 감지를 하지 않는다
@test "an explicit target skips auto detection" {
    setup_merged_feature
    use_github_remote
    stub_gh "printf 'main\n'"

    run "$GIT_PR_DONE" --target develop --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"develop"* ]]
    [[ "$output" == *"--target"* ]]
    [ -z "$(gh_args)" ]
}

# --target 이 없으면 감지된 브랜치를 타겟으로 쓴다
# (기존 하드코딩 기본값이던 develop 이 아닌 값으로 검증해야 의미가 있다)
@test "the detected branch becomes the target when no target is given" {
    make_branch "feat"
    merge_branch "feat" "main"
    push_all
    git checkout --quiet "feat"
    hide_forge_cli
    git config pr-done.target "main"

    run "$GIT_PR_DONE" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"git checkout main"* ]]
}

# 감지 출처를 실행 계획에 표시한다
@test "the plan summary shows where the target came from" {
    setup_merged_feature
    hide_forge_cli
    git config pr-done.target "develop"

    run "$GIT_PR_DONE" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"pr-done.target"* ]]
}

# gh 가 알려준 base 브랜치가 git 이력 추론 결과보다 우선한다
# (이력 추론이라면 develop 을 고르는 상황에서 gh 는 main 을 알려준다)
@test "the PR base branch detected via gh wins over git inference" {
    make_branch "develop"
    make_branch "feat" "develop"
    merge_branch "feat" "develop"
    merge_branch "develop" "main"
    push_all
    git checkout --quiet "feat"
    use_github_remote
    stub_gh "printf 'main\n'"

    run "$GIT_PR_DONE" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"git checkout main"* ]]
    [[ "$output" != *"git checkout develop"* ]]
}

# 커밋되지 않은 변경이 있으면 감지(네트워크 호출) 전에 먼저 중단한다
@test "a dirty tree aborts before any detection happens" {
    setup_merged_feature
    use_github_remote
    stub_gh "printf 'main\n'"
    echo "dirty" >> file.txt

    run "$GIT_PR_DONE" --dry-run
    [ "$status" -eq 2 ]
    [ -z "$(gh_args)" ]
}

# 감지에 실패하면 exit 2 로 중단하고 해결 방법을 안내한다
@test "failed detection exits 2 and explains how to recover" {
    make_branch "feature-x"
    push_all
    git checkout --quiet "feature-x"
    hide_forge_cli

    run "$GIT_PR_DONE" --dry-run
    [ "$status" -eq 2 ]
    [[ "$output" == *"--target"* ]]
    [[ "$output" == *"pr-done.target"* ]]
}

# 감지에 실패해도 develop 으로 폴백하지 않는다
@test "failed detection never falls back to develop" {
    make_branch "develop"
    make_branch "feature-x"
    push_all
    git checkout --quiet "feature-x"
    hide_forge_cli

    run "$GIT_PR_DONE" --dry-run
    [ "$status" -eq 2 ]
    [[ "$output" != *"git checkout develop"* ]]
}

# 감지된 타겟이 로컬에 없으면 자동 감지 결과임을 알린다
@test "a detected target missing from local is reported as auto detected" {
    setup_merged_feature
    hide_forge_cli
    git config pr-done.target "release/2026-H1"

    run "$GIT_PR_DONE" --dry-run
    [ "$status" -eq 1 ]
    [[ "$output" == *"release/2026-H1"* ]]
    [[ "$output" == *"감지"* ]]
}

# ─────────────────────────────────────────────────────────────
# 인자 검증
# ─────────────────────────────────────────────────────────────

# -t 에 빈 값을 주면 거부한다 (스크립트에서 빈 변수를 넘긴 경우)
@test "an empty --target is rejected instead of silently auto detecting" {
    setup_merged_feature
    use_github_remote
    stub_gh "printf 'main\n'"

    run "$GIT_PR_DONE" --target "" --dry-run
    [ "$status" -eq 1 ]
    [[ "$output" == *"빈 값"* ]]
}

# -b 에 빈 값을 주면 거부한다 (조용히 현재 브랜치로 대체하지 않는다)
@test "an empty --branch is rejected instead of falling back to the current branch" {
    setup_merged_feature

    run "$GIT_PR_DONE" --branch "" --dry-run
    [ "$status" -eq 1 ]
    [[ "$output" == *"빈 값"* ]]
}

# ─────────────────────────────────────────────────────────────
# 검증 순서: 로컬만으로 판정 가능한 검사는 감지보다 먼저
# ─────────────────────────────────────────────────────────────

# 없는 브랜치를 -b 로 주면 감지 전에 그 사실을 알린다
@test "a missing --branch is reported before detection runs" {
    setup_merged_feature
    use_github_remote
    stub_gh "printf 'main\n'"

    run "$GIT_PR_DONE" --branch "no-such-branch" --dry-run
    [ "$status" -eq 1 ]
    [[ "$output" == *"삭제 대상 브랜치가 존재하지 않습니다"* ]]
    [ -z "$(gh_args)" ]
}

# 보호 브랜치를 지우려 하면 감지 전에 거부한다
@test "a protected branch is refused before detection runs" {
    setup_merged_feature
    git checkout --quiet main
    use_github_remote
    stub_gh "printf 'develop\n'"

    run "$GIT_PR_DONE" --dry-run
    [ "$status" -eq 2 ]
    [[ "$output" == *"보호 브랜치"* ]]
    [ -z "$(gh_args)" ]
}

# ─────────────────────────────────────────────────────────────
# 원격 참조 갱신
# ─────────────────────────────────────────────────────────────

# 서버에서만 일어난 머지도 감지한다 (로컬 원격 참조가 낡아 있어도)
@test "a merge that exists only on the server is still detected" {
    make_branch "develop"
    make_branch "feat" "develop"
    push_all
    merge_on_server "feat" "develop"
    git checkout --quiet "feat"
    hide_forge_cli

    run "$GIT_PR_DONE" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"git checkout develop"* ]]
}

# ─────────────────────────────────────────────────────────────
# 머지 증거 사전 검증 (사용자를 옮기기 전에 멈춘다)
# ─────────────────────────────────────────────────────────────

# 머지 안 된 브랜치면 checkout 하기 전에 중단한다
@test "an unmerged branch aborts before the user is moved" {
    make_branch "feat"
    push_all
    git checkout --quiet "feat"
    git config pr-done.target "main"
    hide_forge_cli

    run "$GIT_PR_DONE" -y
    [ "$status" -ne 0 ]
    # 사용자는 자기 브랜치에 그대로 남아 있어야 한다
    [ "$(git symbolic-ref --short HEAD)" = "feat" ]
    git show-ref --verify --quiet refs/heads/feat
}

# 머지 안 된 브랜치를 --force 로 지우려 하면 거부하고 잃을 커밋을 보여준다
@test "--force refuses to delete a branch with no merge evidence" {
    make_branch "feat"
    push_all
    git checkout --quiet "feat"
    git config pr-done.target "main"
    hide_forge_cli

    run "$GIT_PR_DONE" -y --force
    [ "$status" -ne 0 ]
    [[ "$output" == *"work on feat"* ]]        # 잃게 될 커밋을 나열한다
    [[ "$output" == *"git branch -D"* ]]       # 직접 실행하라고 안내한다
    git show-ref --verify --quiet refs/heads/feat
}

# gh 가 머지를 확인해 주면 --force 로 삭제한다 (squash 머지 정리)
@test "--force deletes when the forge confirms the merge" {
    make_branch "feat"
    push_all
    git checkout --quiet "feat"
    use_github_remote
    stub_gh "printf 'main\n'"

    run "$GIT_PR_DONE" -y --force
    [ "$status" -eq 0 ]
    run git show-ref --verify --quiet refs/heads/feat
    [ "$status" -ne 0 ]
}

# git 이력만으로 머지가 확인되면 --force 도 정상 동작한다
@test "--force deletes when git history confirms the merge" {
    make_branch "develop"
    make_branch "feat" "develop"
    merge_branch "feat" "develop"
    push_all
    git checkout --quiet "feat"
    git config pr-done.target "develop"
    hide_forge_cli

    run "$GIT_PR_DONE" -y --force
    [ "$status" -eq 0 ]
    run git show-ref --verify --quiet refs/heads/feat
    [ "$status" -ne 0 ]
}

# 머지되지 않았다는 에러가 --force 를 권하지 않는다
@test "the not-merged error no longer recommends --force" {
    make_branch "feat"
    push_all
    git checkout --quiet "feat"
    git config pr-done.target "main"
    hide_forge_cli

    run "$GIT_PR_DONE" -y
    [[ "$output" != *"--force 로 재실행"* ]]
}

# --help 에 자동 감지 동작을 설명한다
@test "help documents the auto detection behaviour" {
    run "$GIT_PR_DONE" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"자동 감지"* ]]
    [[ "$output" == *"pr-done.target"* ]]
}

# --help 에 develop 이 기본값이라고 적혀 있지 않다
@test "help no longer advertises develop as the default" {
    run "$GIT_PR_DONE" --help
    [ "$status" -eq 0 ]
    [[ "$output" != *"기본: develop"* ]]
}

# --version 은 2.0.0 이다
@test "version reports 2.0.0" {
    run "$GIT_PR_DONE" --version
    [ "$status" -eq 0 ]
    [[ "$output" == *"2.0.0"* ]]
}
