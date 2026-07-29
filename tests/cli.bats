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
    stub_gh_merged "main" "abc1234"

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
    stub_gh_merged "main" "$(git rev-parse feat)"

    run "$GIT_PR_DONE" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"git checkout main"* ]]
    [[ "$output" != *"git checkout develop"* ]]
}

# 커밋되지 않은 변경이 있으면 감지(네트워크 호출) 전에 먼저 중단한다
@test "a dirty tree aborts before any detection happens" {
    setup_merged_feature
    use_github_remote
    stub_gh_merged "main" "abc1234"
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
    stub_gh_merged "main" "abc1234"

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
    stub_gh_merged "main" "abc1234"

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
    stub_gh_merged "develop" "abc1234"

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

# 확인 프롬프트에서 취소하면 아무것도 바뀌지 않은 상태로 남는다
@test "answering no at the prompt leaves the repository untouched" {
    make_branch "develop"
    make_branch "feat" "develop"
    merge_branch "feat" "develop"
    push_all
    git checkout --quiet "feat"
    hide_forge_cli
    # 서버에서 브랜치를 지워 prune 대상이 생기게 한다
    git --git-dir="$TEST_TMP/origin.git" branch -D feat
    BEFORE=$(git for-each-ref --format='%(refname)' refs/remotes/)

    run bash -c "printf 'n\n' | '$GIT_PR_DONE'"
    [ "$status" -eq 3 ]
    [ "$(git for-each-ref --format='%(refname)' refs/remotes/)" = "$BEFORE" ]
    [ "$(git symbolic-ref --short HEAD)" = "feat" ]
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
# 단, PR 이 머지한 커밋이 지금 브랜치 끝과 같아야 한다
@test "--force deletes when the forge confirms the merge of this very commit" {
    make_branch "feat"
    push_all
    git checkout --quiet "feat"
    use_github_remote
    stub_gh_merged "main" "$(git rev-parse feat)"

    run "$GIT_PR_DONE" -y --force
    [ "$status" -eq 0 ]
    run git show-ref --verify --quiet refs/heads/feat
    [ "$status" -ne 0 ]
}

# 같은 이름을 재사용한 과거 PR 은 지금 커밋의 증거가 아니다
@test "--force refuses when the merged PR belongs to a reused branch name" {
    make_branch "fix-typo"
    merge_branch "fix-typo" "main"
    push_all
    git checkout --quiet "fix-typo"
    OLD_SHA=$(git rev-parse HEAD)
    # 같은 브랜치 이름으로 전혀 새로운 작업을 올린다
    echo "재사용된 이름의 새 작업" > brand-new.txt
    git add .
    git commit --quiet -m "새 작업 - 아직 머지 안 됨"
    use_github_remote
    stub_gh_merged "main" "$OLD_SHA"     # gh 는 과거 PR 을 알려준다

    run "$GIT_PR_DONE" -y --force
    [ "$status" -ne 0 ]
    git show-ref --verify --quiet refs/heads/fix-typo
}

# PR 머지 이후 새 커밋을 쌓았으면 --force 로도 지우지 않는다
@test "--force refuses when commits were added after the PR was merged" {
    make_branch "feat"
    push_all
    git checkout --quiet "feat"
    MERGED_SHA=$(git rev-parse HEAD)
    echo "머지 이후 추가 작업" >> file.txt
    git commit --quiet -am "머지 뒤에 추가한 커밋"
    use_github_remote
    stub_gh_merged "main" "$MERGED_SHA"

    run "$GIT_PR_DONE" -y --force
    [ "$status" -ne 0 ]
    [[ "$output" == *"머지 뒤에 추가한 커밋"* ]]
    git show-ref --verify --quiet refs/heads/feat
}

# --force 경로에서도 forge 조회는 한 번만 나간다
@test "--force queries the forge only once" {
    make_branch "feat"
    push_all
    git checkout --quiet "feat"
    use_github_remote
    stub_gh_merged "main" "$(git rev-parse feat)"

    run "$GIT_PR_DONE" -y --force
    [ "$status" -eq 0 ]
    [ "$(gh_args | wc -l | tr -d ' ')" -eq 1 ]
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

# --version 은 1.1.0 이다
@test "version reports 1.1.0" {
    run "$GIT_PR_DONE" --version
    [ "$status" -eq 0 ]
    [[ "$output" == *"1.1.0"* ]]
}

# ─────────────────────────────────────────────────────────────
# --upgrade : 설치된 자기 자신을 최신으로 교체한다
# ─────────────────────────────────────────────────────────────

# 설치본을 흉내내기 위해 스크립트를 임시 위치에 복사하고,
# curl 을 스텁으로 대체해 지정한 버전을 내려받은 것처럼 만든다.
setup_upgrade_fixture() {
    INSTALLED="$TEST_TMP/bin-installed/git-pr-done"
    mkdir -p "$(dirname "$INSTALLED")"
    sed "s/^readonly VERSION=.*/readonly VERSION=\"$1\"/" "$GIT_PR_DONE" > "$INSTALLED"
    chmod 755 "$INSTALLED"

    SERVED="$TEST_TMP/served"
    sed "s/^readonly VERSION=.*/readonly VERSION=\"$2\"/" "$GIT_PR_DONE" > "$SERVED"

    cat > "$STUB_BIN/curl" <<STUB
#!/usr/bin/env bash
dest=""; prev=""
for a in "\$@"; do [[ "\$prev" == "-o" ]] && dest="\$a"; prev="\$a"; done
printf '%s\n' "\$*" >> "$TEST_TMP/curl-args.log"
[[ -n "\$dest" ]] && cp "$SERVED" "\$dest" || cat "$SERVED"
STUB
    chmod +x "$STUB_BIN/curl"
}

@test "--upgrade replaces the installed script with the newer one" {
    setup_upgrade_fixture "1.0.0" "9.9.9"

    run "$INSTALLED" --upgrade -y
    [ "$status" -eq 0 ]
    [ "$("$INSTALLED" --version | awk '{print $2}')" = "9.9.9" ]
    [ -x "$INSTALLED" ]
}

@test "--upgrade keeps the current version when it is already latest" {
    setup_upgrade_fixture "1.0.0" "1.0.0"

    run "$INSTALLED" --upgrade -y
    [ "$status" -eq 0 ]
    [[ "$output" == *"최신"* ]]
    [ "$("$INSTALLED" --version | awk '{print $2}')" = "1.0.0" ]
}

# 내려받은 것이 이 스크립트가 아니면 교체하지 않는다
@test "--upgrade refuses a download that is not git-pr-done" {
    setup_upgrade_fixture "1.0.0" "9.9.9"
    printf '<html>404</html>\n' > "$SERVED"

    run "$INSTALLED" --upgrade -y
    [ "$status" -ne 0 ]
    [ "$("$INSTALLED" --version | awk '{print $2}')" = "1.0.0" ]
}

# 다운로드가 실패해도 기존 파일이 손상되지 않아야 한다
@test "--upgrade leaves the script intact when the download fails" {
    setup_upgrade_fixture "1.0.0" "9.9.9"
    printf '#!/usr/bin/env bash\nexit 22\n' > "$STUB_BIN/curl"
    chmod +x "$STUB_BIN/curl"

    run "$INSTALLED" --upgrade -y
    [ "$status" -ne 0 ]
    [ "$("$INSTALLED" --version | awk '{print $2}')" = "1.0.0" ]
}

# git 저장소 밖에서도 동작해야 한다 (업데이트는 저장소와 무관)
@test "--upgrade works outside a git repository" {
    setup_upgrade_fixture "1.0.0" "9.9.9"
    mkdir -p "$TEST_TMP/not-a-repo"
    cd "$TEST_TMP/not-a-repo"

    run "$INSTALLED" --upgrade -y
    [ "$status" -eq 0 ]
    [ "$("$INSTALLED" --version | awk '{print $2}')" = "9.9.9" ]
}

# 확인 프롬프트에서 거절하면 교체하지 않는다
@test "--upgrade does nothing when the user declines" {
    setup_upgrade_fixture "1.0.0" "9.9.9"

    run bash -c "printf 'n\n' | '$INSTALLED' --upgrade"
    [ "$status" -eq 3 ]
    [ "$("$INSTALLED" --version | awk '{print $2}')" = "1.0.0" ]
}

# --ref 로 내려받을 참조를 바꿀 수 있다
@test "--upgrade honours the PR_DONE_REF override" {
    setup_upgrade_fixture "1.0.0" "9.9.9"

    PR_DONE_REF="v1.0.0" run "$INSTALLED" --upgrade -y
    [ "$status" -eq 0 ]
    [[ "$(cat "$TEST_TMP/curl-args.log")" == *"v1.0.0"* ]]
}
