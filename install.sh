#!/usr/bin/env zsh
set -euo pipefail

DOTFILES_DIR="$HOME/.dotfiles"
BREWFILE_PATH="$DOTFILES_DIR/Brewfile"
ZSHRC_PATH="$HOME/.zshrc"
ZPROFILE_PATH="$HOME/.zprofile"

echo "🔧 Setup Mac M5 COMPLETE | ZSH-SAFE | $(date)"

# Pre-flight
[[ ! -f "$BREWFILE_PATH" ]] && { echo "❌ Brewfile"; exit 1; }

# Helper: append a line to a file only if not already present
append_if_missing() {
  local line="$1" file="$2"
  [[ -f "$file" ]] || touch "$file"
  grep -qF -- "$line" "$file" || echo "$line" >> "$file"
}

# 1. Xcode Command Line Tools
command -v xcode-select >/dev/null 2>&1 || xcode-select --install || true

# 2. Homebrew (install only if missing, then persist shellenv once)
if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
  append_if_missing 'eval "$(/opt/homebrew/bin/brew shellenv)"' "$ZPROFILE_PATH"
fi

# 3. Brew bundle (best-effort: installa tutto il possibile, salta i singoli fallimenti)
# Nota: niente HOMEBREW_NO_INSTALL_FROM_API. Serviva ad aggirare un bug di brew 5.1.8
# nel parsing del JSON dei cask (1password-cli), ma da brew 6.x quel flag rompe il
# fetch di TUTTI i cask. L'installazione via API è ormai il default corretto.
brew update || echo "⚠️  brew update fallito, proseguo con la cache locale"

# brew bundle prova ogni entry e prosegue anche se una fallisce: l'`if` cattura
# l'exit code ≠ 0 così set -e non interrompe lo script, e mostriamo i mancanti.
if brew bundle --file="$BREWFILE_PATH"; then
  echo "✅ Brew bundle: tutti i pacchetti installati"
else
  echo "⚠️  Brew bundle: alcuni pacchetti NON installati. Riepilogo mancanti:"
  brew bundle check --file="$BREWFILE_PATH" --verbose || true
  echo "   (lo script prosegue comunque con gli step successivi)"
fi

# 4. asdf + plugin linguaggi
# asdf ≥ 0.16 è una riscrittura in Go: niente più libexec/asdf.sh, solo binario + shims.
if command -v asdf >/dev/null 2>&1; then
  ASDF_DATA_DIR="${ASDF_DATA_DIR:-$HOME/.asdf}"

  # Rimuovi eventuale source legacy a libexec/asdf.sh (rotto in 0.16+)
  if [[ -f "$ZSHRC_PATH" ]] && grep -q 'libexec/asdf\.sh' "$ZSHRC_PATH"; then
    grep -v 'libexec/asdf\.sh' "$ZSHRC_PATH" > "$ZSHRC_PATH.tmp" && mv "$ZSHRC_PATH.tmp" "$ZSHRC_PATH"
  fi

  # Setup corretto per asdf Go: shims in PATH + completions zsh
  append_if_missing 'export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"' "$ZSHRC_PATH"
  append_if_missing 'fpath=(${ASDF_DATA_DIR:-$HOME/.asdf}/completions $fpath)' "$ZSHRC_PATH"
  append_if_missing 'autoload -Uz compinit && compinit' "$ZSHRC_PATH"

  mkdir -p "$ASDF_DATA_DIR/completions"
  asdf completion zsh > "$ASDF_DATA_DIR/completions/_asdf" 2>/dev/null || true

  add_plugin() {
    local name="$1" url="$2"
    asdf plugin list 2>/dev/null | grep -qx "$name" || asdf plugin add "$name" "$url"
  }
  add_plugin golang https://github.com/kennyp/asdf-golang.git
  add_plugin rust   https://github.com/asdf-community/asdf-rust.git
  add_plugin python https://github.com/danhper/asdf-python.git
  # nodejs gestito da fnm

  echo "✅ asdf + Go/Rust/Python"
fi

# 5. Reload zshrc (best-effort)
source "$ZSHRC_PATH" 2>/dev/null || true

# 6. Node via fnm
command -v fnm >/dev/null 2>&1 && {
  eval "$(fnm env)"
  fnm list | grep -q lts || fnm install --lts
  fnm use lts-latest 2>/dev/null || true
}

# 7. Git config (ZSH-safe)
if ! git config --global user.name >/dev/null 2>&1; then
  echo -n "Git name [Enter=skip]: "
  read GIT_NAME
  [[ -n "$GIT_NAME" ]] && git config --global user.name "$GIT_NAME"

  echo -n "Git email [Enter=skip]: "
  read GIT_EMAIL
  [[ -n "$GIT_EMAIL" ]] && git config --global user.email "$GIT_EMAIL"
fi
git config --global init.defaultBranch main 2>/dev/null || true
git config --global pull.rebase true        2>/dev/null || true
echo "✅ Git"

# 8. SSH key
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

# 9. VS Code extensions (one --install-extension per ext)
if command -v code >/dev/null 2>&1; then
  for ext in \
    dbaeumer.vscode-eslint \
    esbenp.prettier-vscode \
    ms-vscode.vscode-typescript-next \
    ms-azuretools.vscode-docker \
    eamodio.gitlens; do
    code --install-extension "$ext" --force || true
  done
fi

# 10. macOS tweaks
[[ -d /Applications/iTerm.app ]] && {
  defaults write com.googlecode.iterm2 Hotkey -bool true HotkeyKeyCode -int 49 HotkeyModifierFlags -int 262144 2>/dev/null || true
}
defaults write -g InitialKeyRepeat -int 15 KeyRepeat -int 1 2>/dev/null || true
defaults write com.apple.dock autohide -bool true 2>/dev/null || true
killall Dock Finder 2>/dev/null || true

echo "🎉 100% COMPLETO! source ~/.zshrc"
