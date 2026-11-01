#!/usr/bin/env bash
# Fuzzy-pick a tmux session or a project directory and switch to it.
# Existing sessions come first, with the active pane's title (e.g. an agent's current task) and directory;
# the preview shows what's on screen in the session (or the directory's contents).
# enter: switch to the session, or create one named after the directory    ctrl-x: kill the session

# Besides the folders in ~, git repos one level further down (~/folder/repo) are listed
REPO_DEPTH=3
# macOS home folders that are never projects (and too big to search)
SKIP_DIRS=("$HOME/Applications" "$HOME/Library" "$HOME/Movies" "$HOME/Music" "$HOME/Pictures" "$HOME/Public")

# Prints project directories, one per line
projects() {
    local skip=() dir
    for dir in "${SKIP_DIRS[@]}"; do skip+=(-o -path "$dir"); done
    find "$HOME" -mindepth 1 -maxdepth 1 -type d ! -name '.*'
    # Hidden folders and dependencies are never searched
    find "$HOME" -mindepth 1 -maxdepth "$REPO_DEPTH" \
        \( -type d \( -name '.*' ! -name .git -o -name node_modules "${skip[@]}" \) -prune \) -o \
        -name .git -prune -print | sed 's|/\.git$||'
}

# Prints "<kind>\t<target>\t<label>" lines; fzf only shows and matches the label
list() {
    tmux list-sessions -F $'#{session_name}\t#{session_windows}\t#{pane_current_path}\t#{pane_title}\t#{session_attached}\t#{host_short}' 2>/dev/null |
        awk -F'\t' -v home="$HOME" '{
            sub("^" home, "~", $3)
            # Skip titles that only repeat the directory (fish) or the hostname (tmux default)
            title = ($4 == "" || $4 == $3 || $4 == $6) ? "" : $4 "  ·  "
            printf "session\t%s\t◆ %s  ·  %s%s  ·  %d window%s%s\n", $1, $1, title, $3, $2, ($2 == 1 ? "" : "s"), ($5 > 0 ? "  (attached)" : "")
        }'
    projects 2>/dev/null | sort -u | grep -v -x -F -f <(printf '%s\n' "${SKIP_DIRS[@]}") |
        awk -v home="$HOME" '{ label = $0; sub("^" home, "~", label); printf "dir\t%s\t  %s\n", $0, label }'
}

if [ "$1" = --list ]; then
    list
    exit 0
fi

selected=$(
    # --with-shell: fzf runs preview/bind commands with $SHELL otherwise, which is fish
    list | fzf --tmux center,80%,80% --prompt="session> " --with-shell='bash -c' \
        --delimiter=$'\t' --with-nth=3 \
        --header="enter: open  ·  ctrl-x: kill session" \
        --preview='if [ {1} = session ]; then tmux capture-pane -ep -t ={2}:; else ls -A {2}; fi' \
        --preview-window=right,50% \
        --bind="ctrl-x:execute-silent([ {1} = session ] && tmux kill-session -t ={2})+reload(bash '$0' --list)"
)

[ -z "$selected" ] && exit 0
IFS=$'\t' read -r kind target _ <<< "$selected"

if [ "$kind" = session ]; then
    tmux switch-client -t "=$target"
    exit 0
fi

# Session names can't contain dots or colons
session_name=$(basename "$target" | tr '.:' '__')
tmux has-session -t "=$session_name" 2>/dev/null || tmux new-session -d -s "$session_name" -c "$target"
tmux switch-client -t "=$session_name"
