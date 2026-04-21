# Nix Home Manager Setup

Declarative home environment using [Nix flakes](https://nixos.wiki/wiki/Flakes) and
[home-manager](https://github.com/nix-community/home-manager). Works on Linux (x86_64)
and macOS (Apple Silicon and Intel).

## What is managed

| What | How |
|------|-----|
| Packages | `home.packages` in `nix/home/default.nix` |
| Git config | `programs.git.settings` → `~/.config/git/config` |
| Zsh + oh-my-zsh | `programs.zsh` → `~/.zshrc` |
| Starship prompt | `programs.starship.settings` → `~/.config/starship.toml` |
| Atuin, fzf, zoxide | `programs.*` with zsh integration |
| Jujutsu config | `home.file` text → `~/.config/jj/config.toml` |
| Ghostty config | `home.file` text → `~/.config/ghostty/config` |

`~/.gitconfig` is intentionally left unmanaged so `gh auth login` can write credential
helpers there. Git reads both `~/.gitconfig` and `~/.config/git/config`.

## Bootstrap on a new machine

### 1. Install Nix

```bash
# Determinate installer (recommended — enables flakes by default)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

If using the official installer instead, enable flakes manually:

```bash
mkdir -p ~/.config/nix
echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
```

### 2. Clone dotfiles

```bash
jj git clone https://github.com/madhusudancs/dotfiles.git ~/code/dotfiles
cd ~/code/dotfiles
```

### 3. Apply configuration

```bash
# Linux (x86_64) — --impure required for nixGL GPU auto-detection
nix run 'github:nix-community/home-manager' -- switch --impure --flake .#madhu-linux

# macOS — Apple Silicon
nix run 'github:nix-community/home-manager' -- switch --flake .#madhu-darwin

# macOS — Intel
nix run 'github:nix-community/home-manager' -- switch --flake .#madhu-darwin-x86
```

### 4. Linux only: set default shell

The activation script can't run `sudo` non-interactively, so run this once manually
to register the Nix zsh and set it as your login shell:

```bash
echo "$(which zsh)" | sudo tee -a /etc/shells && chsh -s "$(which zsh)"
```

### 5. Post-setup

Re-authenticate GitHub CLI so it can write its credential helper to `~/.gitconfig`:

```bash
gh auth login
```

The Rust stable toolchain, Serena MCP server, and Claude Code plugins (starship-claude,
ghostty-notifications) are all installed automatically by `home-manager switch` via
activation scripts. The plugin installs require SSH access to GitHub — they will retry
silently on each switch until Bitwarden's SSH agent is running.

After starship-claude is installed, run `/starship` inside a Claude Code session to
run the setup wizard (pick palette, font, style).

## Day-to-day usage

After the initial bootstrap, `home-manager` is in `~/.nix-profile/bin/`:

```bash
# Apply changes after editing nix/home/*.nix
home-manager switch --impure --flake ~/code/dotfiles#madhu-linux

# Update all inputs to latest (nixpkgs, home-manager, nixgl)
nix flake update ~/code/dotfiles
home-manager switch --impure --flake ~/code/dotfiles#madhu-linux
```

## Adding packages

Edit `home.packages` in `nix/home/default.nix`, then run `home-manager switch`.

Search for packages at <https://search.nixos.org/packages>.

## File structure

```
dotfiles/
├── flake.nix               # Inputs (nixpkgs-unstable, home-manager) and outputs
├── flake.lock              # Pinned dependency versions
└── nix/home/
    ├── default.nix         # Shared: packages, git, zsh, starship, jj, ghostty
    ├── linux.nix           # Linux overrides: homedir, credential helper, SSH_AUTH_SOCK
    └── darwin.nix          # macOS overrides: homedir, credential helper
```
