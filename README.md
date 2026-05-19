# .dotfiles

Bootstrap macOS personale: `Brewfile` + script di setup `install.sh` zsh-safe e idempotente.

## Prerequisiti

- macOS (Apple Silicon)
- Account Apple già configurato sulla macchina

## Uso

```sh
git clone <repo-url> ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

Lo script è idempotente: ripeterlo non duplica righe in `~/.zshrc`/`~/.zprofile` né reinstalla plugin asdf già presenti.

## Cosa fa

1. Installa Xcode Command Line Tools e Homebrew (se mancanti)
2. Esegue `brew bundle` sul `Brewfile`
3. Configura `asdf` (Go, Rust, Python) e `fnm` (Node LTS)
4. Imposta `git` (nome/email interattivi al primo run, `init.defaultBranch=main`, `pull.rebase=true`)
5. Genera SSH key ed25519 (opzionale)
6. Installa un set base di estensioni VS Code
7. Applica tweak macOS: key repeat, dock autohide, iTerm hotkey

## Note

`HOMEBREW_NO_INSTALL_FROM_API=1` è un workaround per un bug di parsing JSON di brew 5.1.8 che impatta il cask `1password-cli`. Rimuovibile quando il fix arriva upstream.
