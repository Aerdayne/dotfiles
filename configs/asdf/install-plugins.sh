# !/usr/bin/env bash

# https://github.com/asdf-vm/asdf/issues/659

/opt/homebrew/opt/asdf/libexec/bin/asdf plugin-add ruby https://github.com/asdf-vm/asdf-ruby.git
status_code=$?
if [ $status_code -eq 0 ] || [ $status_code -eq 2 ]; then
    echo "Plugin is installed"
elif [ $status_code -eq 1 ]; then
    exit 1
fi

/opt/homebrew/opt/asdf/libexec/bin/asdf plugin-add direnv https://github.com/asdf-community/asdf-direnv
status_code=$?
if [ $status_code -eq 0 ] || [ $status_code -eq 2 ]; then
    echo "Plugin is installed"
elif [ $status_code -eq 1 ]; then
    exit 1
fi
asdf direnv setup --shell fish --version latest

/opt/homebrew/opt/asdf/libexec/bin/asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
status_code=$?
if [ $status_code -eq 0 ] || [ $status_code -eq 2 ]; then
    echo "Plugin is installed"
elif [ $status_code -eq 1 ]; then
    exit 1
fi