if status is-interactive
    abbr --add ls eza
    abbr --add ll 'eza -l --git'
    abbr --add la 'eza -la --git'
    abbr --add cat 'bat --paging=never'
    abbr --add find fd # skips hidden and .gitignored files unless given -H / -I
    abbr --add du dust
    abbr --add top htop
end
