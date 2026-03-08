#!/usr/bin/env zsh
set -euo pipefail

DOTFILES_DIR="$HOME/.dotfiles"
BREWFILE_PATH="$DOTFILES_DIR/Brewfile"
ZSHRC_PATH="$HOME/.zshrc"

echo "🔧 Setup Mac M5 COMPLETE | ZSH-SAFE | $(date)"

# Pre-flight
[[ ! -f "$BREWFILE_PATH" ]] && { echo "❌ Brewfile"; exit 1; }

# 1-3. Core (già OK)
command -v xcode-select >/dev/null 2>&1 || xcode-select --install || true
command -v brew >/dev/null 2>&1 || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && eval "$(/opt/homebrew/bin/brew shellenv)" && echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
brew update && brew bundle --file="$BREWFILE_PATH" --force

# asdf setup + plugin linguaggi
if command -v asdf >/dev/null 2>&1; then
  # Aggiungi a ~/.zshrc (idempotente)
  [[ ! -f ~/.asdf/asdf.sh ]] || {
    echo '. $(brew --prefix asdf)/libexec/asdf.sh' >> "$ZSHRC_PATH"
    echo '. $(brew --prefix asdf)/plugins/nodejs/shims/asdf' >> "$ZSHRC_PATH" 
  }
  
  # Plugin per progetto
  asdf plugin add golang https://github.com/kennyp/asdf-golang.git
  asdf plugin add rust https://github.com/asdf-community/asdf-rust.git 
  asdf plugin add python https://github.com/pyenv/pyenv.git
  #asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git  # Integra fnm
  
  echo "✅ asdf + Go/Rust/Python"
fi


# 4. zshrc (già OK)
source "$ZSHRC_PATH" 2>/dev/null || true

# 5. Node (già OK)
command -v fnm >/dev/null 2>&1 && {
  eval "$(fnm env)"
  fnm list | grep -q lts || fnm install --lts
  fnm use lts-latest
}

# 6. Git ZSH-SAFE
if ! git config --global user.name >/dev/null 2>&1; then
  echo -n "Git name [Enter=skip]: "
  read GIT_NAME
  [[ -n "$GIT_NAME" ]] && git config --global user.name "$GIT_NAME"
  
  echo -n "Git email [Enter=skip]: "
  read GIT_EMAIL
  [[ -n "$GIT_EMAIL" ]] && git config --global user.email "$GIT_EMAIL"
fi
git config --global init.defaultBranch main pull.rebase true 2>/dev/null || true
echo "✅ Git"

# 7. SSH ZSH-SAFE
SSH_KEY="$HOME/.ssh/id_ed25519"
[[ -f "$SSH_KEY" ]] || {
  echo -n "Genera SSH key? [y/N]: "
  read -k1 -u0 ANSWER 2>/dev/null || read ANSWER
  if [[ "$ANSWER" =~ [Yy] ]]; then
    echo -n "Email: "
    read SSH_EMAIL
    ssh-keygen -t ed25519 -C "$SSH_EMAIL" -f "$SSH_KEY" -N ""
    ssh-add "$SSH_KEY"
    pbcopy < "$SSH_KEY.pub"
    echo "✅ SSH key copiata"
  fi
}

# 8. VS Code
command -v code >/dev/null 2>&1 && code --install-extension dbaeumer.vscode-eslint esbenp.prettier-vscode ms-vscode.vscode-typescript-next ms-azuretools.vscode-docker eamodio.gitlens --force || true

# 9-10. Tweaks
[[ -d /Applications/iTerm.app ]] && {
  defaults write com.googlecode.iterm2 Hotkey -bool true HotkeyKeyCode -int 49 HotkeyModifierFlags -int 262144 2>/dev/null || true
}
defaults write -g InitialKeyRepeat -int 15 KeyRepeat -int 1 2>/dev/null || true
defaults write com.apple.dock autohide -bool true 2>/dev/null || true
killall Dock Finder 2>/dev/null || true

echo "🎉 100% COMPLETO! source ~/.zshrc"
