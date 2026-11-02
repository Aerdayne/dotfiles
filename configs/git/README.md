# Git accounts

Commits, pushes and gh use the account for whoever owns the repository on GitHub, so a fresh clone needs no settings of its own. The owner is the user or organisation in the repository's URL, `github.com/OWNER/REPO`. There are two accounts, personal and work, set up per Mac with `git account add`. They live in `~/.config/git/accounts`, outside this repository, where `config` maps owners to accounts with `includeIf "hasconfig:remote.*.url:…"` entries.

- `git account`: which account this repository uses, and why
- `git account list`: the accounts, and the owners each one is for
- `git account as work commit -m "…"`: one git command as work, such as a commit or a push
- `git account use work`: this repository uses work from now on, whoever owns it; the prompt shows `(chosen)` until `git account reset`
- `git account map work OWNER`: every repository owned by OWNER uses work too, for a new work organisation say

A repository whose owner has no account, such as a clone of someone else's project, can't commit until it has one, and the prompt shows `no git account` where the account would be. It still fetches, with the personal key.

Identities don't go in `~/.gitconfig` (`git config --global user.email`): git reads it after the accounts, so it would override them in every repository. The prompt shows `global git identity` if one gets there.

gh goes through `~/.local/bin/gh`, which runs it as the account for what it acts on: the owner given with `-R OWNER/REPO` or as the repository or URL a command works on, else the repository it's run in, else personal, the default account. It stops if that account isn't logged in to gh rather than use another one. gh's own active account (`gh auth switch`) only matters to programs that run gh without `~/.local/bin` on their PATH.

## On a new Mac

`./install` reminds you when there are no accounts yet. Log both GitHub accounts in to gh first, with the scope that lets `git account add` put each new SSH key on GitHub:

```bash
gh auth login --scopes admin:public_key   # once as each account
git account add personal --email daenskus@gmail.com --github Aerdayne --default
git account add work --email WORK_EMAIL --github WORK_USER --owner WORK_ORG
```
