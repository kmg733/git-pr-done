#!/usr/bin/env bats
#
# install.sh 동작 테스트
#
# 네트워크를 쓰지 않는다. curl 을 스텁으로 대체해 저장소의 실제 파일을 내려받은 것처럼 흉내낸다.

setup() {
    load "helpers/common"
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    INSTALL_SH="$PROJECT_ROOT/install.sh"

    TEST_TMP="$(mktemp -d)"
    FAKE_HOME="$TEST_TMP/home"
    STUB_BIN="$TEST_TMP/bin"
    mkdir -p "$FAKE_HOME" "$STUB_BIN"

    # 내려받을 원본 (실제 저장소 파일)
    SERVED="$TEST_TMP/served-git-pr-done"
    cp "$PROJECT_ROOT/git-pr-done" "$SERVED"

    stub_curl
    PATH="$STUB_BIN:$PATH"
    export PATH HOME="$FAKE_HOME"
}

teardown() {
    cd / || true
    [[ -n "${TEST_TMP:-}" && -d "$TEST_TMP" ]] && rm -rf "$TEST_TMP"
}

# curl <flags> <url> -o <dest> 형태를 가로채 $SERVED 를 dest 로 복사한다.
stub_curl() {
    cat > "$STUB_BIN/curl" <<STUB
#!/usr/bin/env bash
dest=""
prev=""
for a in "\$@"; do
    if [[ "\$prev" == "-o" ]]; then dest="\$a"; fi
    prev="\$a"
done
printf '%s\n' "\$*" >> "$TEST_TMP/curl-args.log"
if [[ -n "\$dest" ]]; then
    cp "$SERVED" "\$dest"
else
    cat "$SERVED"
fi
STUB
    chmod +x "$STUB_BIN/curl"
}

# 내려받을 원본의 버전을 바꾼다 (업데이트 시나리오용)
serve_version() {
    sed "s/^readonly VERSION=.*/readonly VERSION=\"$1\"/" \
        "$PROJECT_ROOT/git-pr-done" > "$SERVED"
}

installed_version() {
    "$FAKE_HOME/.local/bin/git-pr-done" --version 2>/dev/null | awk '{print $2}'
}

# ─────────────────────────────────────────────────────────────
# 설치
# ─────────────────────────────────────────────────────────────

@test "installs the script and makes it executable" {
    run bash "$INSTALL_SH"
    [ "$status" -eq 0 ]
    [ -f "$FAKE_HOME/.local/bin/git-pr-done" ]
    [ -x "$FAKE_HOME/.local/bin/git-pr-done" ]
}

@test "reports where it installed and how to verify" {
    run bash "$INSTALL_SH"
    [ "$status" -eq 0 ]
    [[ "$output" == *".local/bin/git-pr-done"* ]]
    [[ "$output" == *"git pr-done"* ]]
}

@test "adds the install directory to PATH in the shell rc" {
    run bash "$INSTALL_SH"
    [ "$status" -eq 0 ]
    grep -q '.local/bin' "$FAKE_HOME/.zshrc" "$FAKE_HOME/.bashrc" "$FAKE_HOME/.profile" 2>/dev/null
}

# 두 번 실행해도 PATH 줄이 중복되지 않아야 한다
@test "does not duplicate the PATH line when run twice" {
    bash "$INSTALL_SH" >/dev/null
    bash "$INSTALL_SH" >/dev/null
    local count
    count=$(cat "$FAKE_HOME"/.zshrc "$FAKE_HOME"/.bashrc "$FAKE_HOME"/.profile 2>/dev/null \
            | grep -c 'local/bin' || true)
    [ "$count" -le 1 ]
}

@test "installs to a directory given with --dir" {
    run bash "$INSTALL_SH" --dir "$TEST_TMP/custom"
    [ "$status" -eq 0 ]
    [ -x "$TEST_TMP/custom/git-pr-done" ]
}

@test "skips touching the shell rc with --no-path" {
    run bash "$INSTALL_SH" --no-path
    [ "$status" -eq 0 ]
    [ ! -f "$FAKE_HOME/.zshrc" ]
    [ ! -f "$FAKE_HOME/.bashrc" ]
}

# ─────────────────────────────────────────────────────────────
# 업데이트 (같은 명령 재실행)
# ─────────────────────────────────────────────────────────────

@test "reports an upgrade when a newer version is served" {
    serve_version "1.0.0"
    bash "$INSTALL_SH" >/dev/null
    [ "$(installed_version)" = "1.0.0" ]

    serve_version "9.9.9"
    run bash "$INSTALL_SH"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1.0.0"* ]]
    [[ "$output" == *"9.9.9"* ]]
    [ "$(installed_version)" = "9.9.9" ]
}

@test "says it is already current when the same version is served" {
    serve_version "1.0.0"
    bash "$INSTALL_SH" >/dev/null

    run bash "$INSTALL_SH"
    [ "$status" -eq 0 ]
    [[ "$output" == *"최신"* ]]
}

# ─────────────────────────────────────────────────────────────
# 안전장치
# ─────────────────────────────────────────────────────────────

# 내려받은 파일이 이 스크립트가 아니면 설치하지 않는다
@test "refuses to install a file that is not git-pr-done" {
    printf '<html>404</html>\n' > "$SERVED"

    run bash "$INSTALL_SH"
    [ "$status" -ne 0 ]
    [ ! -f "$FAKE_HOME/.local/bin/git-pr-done" ]
}

# 다운로드가 실패하면 기존 설치본을 건드리지 않는다
@test "leaves an existing install untouched when the download fails" {
    serve_version "1.0.0"
    bash "$INSTALL_SH" >/dev/null

    cat > "$STUB_BIN/curl" <<'STUB'
#!/usr/bin/env bash
exit 22
STUB
    chmod +x "$STUB_BIN/curl"

    run bash "$INSTALL_SH"
    [ "$status" -ne 0 ]
    [ "$(installed_version)" = "1.0.0" ]
}

# ─────────────────────────────────────────────────────────────
# 제거
# ─────────────────────────────────────────────────────────────

@test "--uninstall removes the installed script" {
    bash "$INSTALL_SH" >/dev/null
    [ -f "$FAKE_HOME/.local/bin/git-pr-done" ]

    run bash "$INSTALL_SH" --uninstall
    [ "$status" -eq 0 ]
    [ ! -f "$FAKE_HOME/.local/bin/git-pr-done" ]
}

@test "--uninstall is not an error when nothing is installed" {
    run bash "$INSTALL_SH" --uninstall
    [ "$status" -eq 0 ]
}

# ─────────────────────────────────────────────────────────────
# 파이프 실행 (curl | bash) 에서도 동작해야 한다
# ─────────────────────────────────────────────────────────────

# stdin 이 스크립트 본문이므로 사용자 입력을 기다리면 안 된다
@test "runs to completion when piped into bash" {
    run bash -c "cat '$INSTALL_SH' | bash"
    [ "$status" -eq 0 ]
    [ -x "$FAKE_HOME/.local/bin/git-pr-done" ]
}

@test "accepts flags when piped into bash" {
    run bash -c "cat '$INSTALL_SH' | bash -s -- --dir '$TEST_TMP/piped'"
    [ "$status" -eq 0 ]
    [ -x "$TEST_TMP/piped/git-pr-done" ]
}
