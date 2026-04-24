{ config, pkgs, lib, zig-overlay, system, ... }:

{
  home.stateVersion = "24.11";
  programs.home-manager.enable = true;

  # ── Packages ──────────────────────────────────────────────────────────────
  # atuin, fzf, starship, zoxide are managed via programs.* modules below.

  home.packages = with pkgs; [
    # Version control
    jujutsu
    jj-starship
    gh

    # Editors
    helix
    zed-editor
    nil              # Nix language server (used by Zed, Helix, etc.)
    # zed-editor installs as `zeditor`; this wrapper provides the `zed` name
    # used throughout configs (EDITOR, jj, etc.)
    (pkgs.writeShellScriptBin "zed" ''exec ${pkgs.zed-editor}/bin/zeditor "$@"'')

    # Terminal multiplexer
    zellij

    # Dev workflow
    tilt
    claude-code
    zsh

    # Search & navigation
    ripgrep
    fd
    bat
    eza
    tree

    # Diff tools
    delta
    difftastic
    diffnav

    # Data & network
    jq
    curl
    wget

    # System
    htop

    # Fonts (referenced by Ghostty config)
    nerd-fonts._0xproto   # 0xProto Nerd Font Mono
    nerd-fonts.symbols-only  # Symbols Nerd Font

    # Runtimes & toolchain managers
    # rustup manages rustc/cargo — stable toolchain installed by home.activation below
    rustup
    go           # latest stable Go; tracks nixpkgs-unstable
    nodejs_latest # latest Node.js (non-LTS); use `nodejs` for LTS
    pnpm         # latest pnpm; tracks nixpkgs-unstable
    uv           # includes uvx; zoxide is managed by programs.zoxide below
    zig-overlay.packages.${system}."0.16.0"

  ];

  # ── Git ───────────────────────────────────────────────────────────────────
  # Writes to ~/.config/git/config (XDG). ~/.gitconfig is left unmanaged
  # so `gh auth login` can write credential helpers there freely.

  programs.git = {
    enable = true;
    signing.format = null;
    settings = {
      user = {
        name = "Madhu C.S.";
        email = "madhusudancs@gmail.com";
      };
      alias = {
        fw = "!git commit -qam 'fix whitespace' && git rebase -q --whitespace=fix HEAD~ && git reset -q HEAD~";
        ap = "!git add -p";
        st = "status";
        sh = "!git show -p HEAD";
        l = "log";
        svn-diff = "!git-svn-diff";
      };
      init.defaultBranch = "main";
      push.default = "simple";
      http.cookiefile = "${config.home.homeDirectory}/.gitcookies";
      core.pager = "delta";
      interactive.diffFilter = "delta --color-only";
      delta = {
        navigate = true;
        dark = true;
      };
      merge.conflictStyle = "zdiff3";
      color = {
        ui = "auto";
        branch = "auto";
        diff = "auto";
        status = "auto";
      };
      "color \"branch\"" = {
        current = "yellow reverse";
        local = "yellow";
        remote = "green";
      };
      "color \"diff\"" = {
        meta = "yellow bold";
        frag = "magenta bold";
        old = "red bold";
        new = "green bold";
      };
      "color \"status\"" = {
        added = "yellow";
        changed = "green";
        untracked = "cyan";
      };
    };
  };

  # ── Zsh ───────────────────────────────────────────────────────────────────

  programs.zsh = {
    enable = true;
    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = [ "git" ];
    };
    shellAliases = {
      cat = "bat";
    };
    sessionVariables = {
      MANPAGER = "bat -plman";
      EDITOR = "zed -w";
      USE_BUILTIN_RIPGREP = "0";
    };
    initContent = ''
      export PATH="$HOME/.nix-profile/bin:$HOME/bin:$HOME/.local/bin:$HOME/go/bin:/usr/local/bin:$PATH"

      # Rust/cargo (managed by rustup — run `rustup toolchain install stable` once)
      [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

      source <(jj util completion zsh)

      # pnpm
      export PNPM_HOME="$HOME/.local/share/pnpm"
      case ":$PATH:" in
        *":$PNPM_HOME:"*) ;;
        *) export PATH="$PNPM_HOME:$PATH" ;;
      esac

      # Global bat help aliases
      alias -g -- -h='-h 2>&1 | bat --language=help --style=plain'
      alias -g -- --help='--help 2>&1 | bat --language=help --style=plain'
    '';
  };

  # ── Starship ──────────────────────────────────────────────────────────────

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      add_newline = true;
      character.success_symbol = "[➜ ](bold green)";
      package.disabled = true;
      # Disable all git modules (using jj instead)
      git_branch.disabled = true;
      git_commit.disabled = true;
      git_state.disabled = true;
      git_metrics.disabled = true;
      git_status.disabled = true;
      # jj-starship: unified jj/git prompt module
      custom.jj = {
        command = "jj-starship";
        when = "jj-starship detect";
        format = "$output ";
      };
    };
  };

  # ── Shell tools ───────────────────────────────────────────────────────────

  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # ── Jujutsu ───────────────────────────────────────────────────────────────

  home.file.".config/jj/config.toml".text = ''
    [user]
    name = "Madhu C.S."
    email = "madhusudancs@gmail.com"

    [signing]
    backend = "ssh"
    key = "${config.home.homeDirectory}/.ssh/commit-signing-key.pub"
    behavior = "force"

    [signing.backends.ssh]
    allowed-signers = "~/.ssh/allowed_signers"

    [git]
    sign-on-push = true

    [remotes.origin]
    auto-track-bookmarks = "*"
    auto-track-created-bookmarks = "*"

    [templates]
    git_push_bookmark = '"madhu/" ++ change_id.short()'
    draft_commit_description = "builtin_draft_commit_description_with_diff"

    [template-aliases]
    'format_short_signature(signature)' = 'signature'

    [ui]
    bookmark-list-sort-keys = ["committer-date"]
    conflict-marker-style = "snapshot"
    default-command = ["log", "--no-pager", "-n=5"]
    editor = "zed -w"
    graph.style = "curved"
    wrapping = "word"
    log-word-wrap = true
    movement.edit = true
    diff-formatter = ":git"
    paginate = "auto"
    show-cryptographic-signatures = true

    [ui.streampager]
    interface = "quit-if-one-page"

    [[--scope]]
    --when.commands = ["diff", "show", "interdiff", "obslog"]
    [--scope.ui]
    pager = "diffnav"

    [aliases]
    tip = ["edit", "-r", "latest(heads(mutable()))"]
    la = ["log", "-r", "all()", "--limit", "60"]
  '';

  # ── Claude Code ───────────────────────────────────────────────────────────

  home.file.".claude/CLAUDE.md".text = ''
    # User Instructions

    ## Version Control
    - MUST use `jj` (Jujutsu) for all VCS operations. Never use `git` commands directly.

    ## Regex Search
    - MUST use `rg` (ripgrep) for searching file contents. Never use `grep` directly.

    ## File Search
    - MUST use `fd` for finding files. Never use `find` directly.
  '';

  # ── Ghostty ───────────────────────────────────────────────────────────────

  home.file.".config/ghostty/config".text = ''
    # NOTE: useful tips
    # cmd+<triple-mouse-click>  copy command output
    # cmd+shift+c               copy selected text inside of neovim
    # cmd+shift+v               paste mouse selection (vs cmd+v for keyboard selection)
    # super == cmd
    # page_up/page_down == fn + arrow key
    # IMPORTANT: System Preferences > Notifications > Enable Ghostty

    adjust-cell-height = +20%
    auto-update = check
    auto-update-channel = tip
    bell-audio-volume = 1
    bell-features = system,audio,attention,title,border
    clipboard-paste-protection = true
    clipboard-trim-trailing-spaces = true
    copy-on-select = clipboard
    notify-on-command-finish = always
    notify-on-command-finish-action = bell,notify
    notify-on-command-finish-after = 5s
    quick-terminal-autohide = false
    quick-terminal-position = center
    quick-terminal-size = 75%,75%
    scrollback-limit = 1000000000
    shell-integration = zsh
    split-divider-color = #666666
    split-inherit-working-directory = true
    tab-inherit-working-directory = true
    unfocused-split-opacity = 0.40
    window-inherit-working-directory = false
    window-new-tab-position = end
    window-padding-x = 20
    window-padding-y = 15
    window-save-state = always

    keybind = performable:ctrl+v=paste_from_clipboard
    keybind = performable:super+v=paste_from_clipboard

    desktop-notifications = true

    # Theme: Fun Forrest
    theme = Fun Forrest
    background = #251200
    foreground = #dec165
    selection-background = #e5591c
    selection-foreground = #000000
    cursor-color = #e5591c
    cursor-text = #000000
    palette = 0=#000000
    palette = 1=#d6262b
    palette = 2=#919c00
    palette = 3=#be8a13
    palette = 4=#4699a3
    palette = 5=#8d4331
    palette = 6=#da8213
    palette = 7=#ddc265
    palette = 8=#7f6a55
    palette = 9=#e55a1c
    palette = 10=#bfc65a
    palette = 11=#ffcb1b
    palette = 12=#7cc9cf
    palette = 13=#d26349
    palette = 14=#e6a96b
    palette = 15=#ffeaa3
    font-size = 16
    font-family = 0xProto Nerd Font Mono
    font-family = Symbols Nerd Font
    font-family = Noto Sans Symbols2
  '';

  # ── Bootstrap activation scripts ──────────────────────────────────────────
  # These run on every `home-manager switch` but are idempotent.

  home.activation = {
    # Install the stable Rust toolchain via rustup (rustup itself comes from Nix).
    rustupInstallStable = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if ! ${pkgs.rustup}/bin/rustup toolchain list 2>/dev/null | grep -q '^stable'; then
        $DRY_RUN_CMD ${pkgs.rustup}/bin/rustup toolchain install stable --no-self-update
      fi
    '';

    # Install the Serena MCP coding assistant via uv tool.
    installSerena = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if ! ${pkgs.uv}/bin/uv tool list 2>/dev/null | grep -q 'serena-agent'; then
        $DRY_RUN_CMD ${pkgs.uv}/bin/uv tool install serena-agent
      fi
    '';

    # Install the starship-claude Claude Code plugin.
    # entryAfter "chshToZsh" ensures zsh is the login shell before running;
    # on macOS the unknown key is silently ignored by the DAG resolver.
    installStarshipClaude = lib.hm.dag.entryAfter [ "writeBoundary" "chshToZsh" ] ''
      _claude="${config.home.homeDirectory}/.local/bin/claude"
      if ! "$_claude" plugins list 2>/dev/null | grep -q 'starship-claude'; then
        $DRY_RUN_CMD "$_claude" plugins marketplace add https://github.com/martinemde/starship-claude.git || true
        $DRY_RUN_CMD "$_claude" plugins install starship-claude@starship-claude || true
      fi
    '';

    # Install the ghostty-notifications Claude Code plugin.
    installGhosttyNotifications = lib.hm.dag.entryAfter [ "writeBoundary" "chshToZsh" ] ''
      _claude="${config.home.homeDirectory}/.local/bin/claude"
      if ! "$_claude" plugins list 2>/dev/null | grep -q 'ghostty-notifications'; then
        $DRY_RUN_CMD "$_claude" plugins marketplace add https://github.com/recursechat/agent-workflow.git || true
        $DRY_RUN_CMD "$_claude" plugins install ghostty-notifications@recursechat-agent-workflow || true
      fi
    '';

    # Install the jj-vcs Claude Code skill from GitHub.
    installJjVcsSkill = lib.hm.dag.entryAfter [ "writeBoundary" "chshToZsh" ] ''
      if [ ! -f "$HOME/.claude/skills/jj-vcs/SKILL.md" ]; then
        _tmpdir=$(mktemp -d)
        trap 'rm -rf "$_tmpdir"' EXIT
        $DRY_RUN_CMD ${pkgs.git}/bin/git clone --quiet --depth 1 \
          https://github.com/danverbraganza/jujutsu-skill "$_tmpdir" || true
        if [ -d "$_tmpdir/skill" ]; then
          $DRY_RUN_CMD mkdir -p "$HOME/.claude/skills/jj-vcs"
          $DRY_RUN_CMD cp -r "$_tmpdir/skill/." "$HOME/.claude/skills/jj-vcs/"
        fi
      fi
    '';
  };
}
