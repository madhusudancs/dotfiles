{ config, pkgs, lib, zig-overlay, system, ... }:

let
  # Directory handed to sandboxed pi sessions via JJ_CONFIG. JJ_CONFIG *replaces*
  # the user config rather than layering on top of it, so this dir has to carry
  # a full copy (00-user.toml) before the sandbox override (99-sandbox.toml)
  # can apply. jj loads a JJ_CONFIG directory's *.toml in sorted order.
  jjSandboxConfigDir = ".config/jj/pi-sandbox";
in

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
    nil              # Nix language server (used by Zed, Helix, etc.)
    # zed-editor is added per-platform: linux.nix (nixGL-wrapped) / darwin.nix

    # Terminal multiplexer
    zellij

    # Dev workflow
    tilt
    claude-code
    nono         # nono CLI (nolabs-ai) — https://nono.sh/docs/cli
    pi-coding-agent  # `pi` — https://pi.dev/
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
      asso = "aws sso login --sso-session resolve";
      pecrl = "aws ecr-public get-login-password --profile=resolve-tools --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws";
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

      # Launch pi in its nono sandbox, granting the one path the profile cannot
      # name: the main repo behind a secondary jj workspace.
      #
      # A secondary workspace's .jj/repo is a *file* holding a path (relative to
      # .jj/) to the main repo's store, e.g. "../../../dotfiles/.jj/repo". That
      # path is data inside the workspace, so no $WORKDIR-relative grant can
      # express it -- and $WORKDIR/.. would hand over every sibling repo. Resolve
      # it here and grant exactly that one .jj directory. The default workspace
      # has a *directory* at .jj/repo and needs nothing extra, since $WORKDIR
      # already covers it. Same thing agent-deck does via --allow.
      #
      # Shadows the pi binary on purpose. No recursion: nono execs pi directly,
      # so the function does not exist in that context.
      pi() {
        local -a extra
        local root repo main
        root=$(command jj workspace root 2>/dev/null)
        if [ -n "$root" ] && [ -f "$root/.jj/repo" ]; then
          repo=$(<"$root/.jj/repo") || return 1
          main=$(cd "$root/.jj" && cd "''${repo:h}" && pwd -P) || return 1
          extra=(--allow "$main")
          # Colocated repos keep the git backend beside .jj, and jj opens that
          # too -- without it you get "does not appear to be a git repository".
          # Metadata dirs only: the main working tree stays out of the sandbox.
          [ -d "''${main:h}/.git" ] && extra+=(--allow "''${main:h}/.git")
        fi
        command nono run --profile pi "''${extra[@]}" -- pi "$@"
      }

      # pnpm
      export PNPM_HOME="$HOME/.local/share/pnpm"
      case ":$PATH:" in
        *":$PNPM_HOME/bin:"*) ;;
        *) export PATH="$PNPM_HOME/bin:$PATH" ;;
      esac

      # bun
      case ":$PATH:" in
        *":$HOME/.bun/bin:"*) ;;
        *) export PATH="$HOME/.bun/bin:$PATH" ;;
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
  # ui.editor below interpolates programs.zsh.sessionVariables.EDITOR rather
  # than hardcoding an editor, so a host that overrides EDITOR (devbox.nix ->
  # "hx", since zed is desktop-only) gets the same editor in jj automatically.

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
    editor = "${config.programs.zsh.sessionVariables.EDITOR}"
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

  # The sandbox variant: the exact same config, plus an override layer. Copied
  # from the attribute above rather than re-stated, so the two cannot drift.
  home.file."${jjSandboxConfigDir}/00-user.toml".text =
    config.home.file.".config/jj/config.toml".text;

  home.file."${jjSandboxConfigDir}/99-sandbox.toml".text = ''
    # Sandboxed pi sessions get no ssh-agent and no ~/.ssh (see the nono profile
    # below), so signing cannot work in there and "force" would make every jj
    # command that writes a commit fail. Drop instead: pi writes unsigned
    # commits, and git.sign-on-push signs them when you push from a normal
    # shell, with the real key, outside the sandbox.
    [signing]
    behavior = "drop"

    # Verification is equally impossible in there (it needs allowed_signers, and
    # jj round-trips the signature through a temp file under /tmp, which the pi
    # pack grants write-only). Without this, jj log renders an error per commit.
    [ui]
    show-cryptographic-signatures = false
  '';

  # ── Claude Code ───────────────────────────────────────────────────────────

  # Starship-claude statusline config (powerline + Catppuccin Mocha + jj-starship).
  # Source file lives in claude-code/starship.toml; kept separate to preserve
  # nerd-font characters that can't be reliably embedded in Nix strings.
  home.file.".claude/starship.toml".source = ../../claude-code/starship.toml;

  home.file.".claude/CLAUDE.md".text = ''
    # User Instructions

    ## Version Control
    - MUST use `jj` (Jujutsu) for all VCS operations. Never use `git` commands directly.

    ## Regex Search
    - MUST use `rg` (ripgrep) for searching file contents. Never use `grep` directly.

    ## File Search
    - MUST use `fd` for finding files. Never use `find` directly.
  '';

  # ── Pi ────────────────────────────────────────────────────────────────────
  # pi coding agent (https://pi.dev/). Settings live in ~/.pi/agent/settings.json,
  # which pi writes to itself (theme/model changes, lastChangelogVersion), so it
  # is merged on activation rather than symlinked read-only from the store.
  # See home.activation.piSettings below for the write.

  # nono sandbox profile for running pi: `nono run --profile pi -- pi`.
  # nono itself is installed out-of-band (`cargo install nono-cli`); only this
  # profile is managed here. It extends the registry-managed nolabs-ai/pi pack,
  # which is signed by .nono-trust.bundle and so must not be edited in place,
  # and adds the three paths pi needs beyond it:
  #   $TMPDIR/jiti                   jiti's TypeScript->mjs transpile cache. pi
  #                                  extensions ship as raw .ts; jiti writes the
  #                                  compiled .mjs then imports it back, so this
  #                                  needs read+write. The pack grants /tmp
  #                                  write-only, which fails the read-back and
  #                                  kills every extension at load.
  #   $TMPDIR/pi-subagents-uid-$UID  pi-subagents' file-based IPC tree. scandir'd
  #                                  at session start to restore async runs.
  #   $WORKDIR                       the project pi is launched in.
  # Directory grants, not per-file: jiti cache filenames are content hashes, so
  # a file-level allowlist goes stale on every pi/extension upgrade.
  # NOTE: launching pi from $HOME fails by design - $WORKDIR would then overlap
  # nono's protected state root ~/.local/state/nono. Launch from a project dir.
  home.file.".config/nono/profiles/pi.json".text = builtins.toJSON {
    extends = [ "nolabs-ai/pi" ];
    meta = {
      name = "pi";
      version = "2.0.0";
      description = "Local additions for pi: jiti transpile cache + pi-subagents IPC dirs";
    };
    filesystem.allow = [
      "$TMPDIR/jiti"
      "$TMPDIR/pi-subagents-uid-$UID"
      "$WORKDIR"
      "$HOME/.config/jj/repos"
    ];
    # Read-only: the JJ_CONFIG dir set below. The .toml files inside are
    # home-manager symlinks into /nix/store (already readable), but jj has to
    # list the directory itself, which $HOME is not otherwise granted for.
    filesystem.read = [ "$HOME/${jjSandboxConfigDir}" ];

    # Keep pi away from the ssh-agent.
    #
    # ~/.ssh is blocked by nono's `deny_credentials` group and stays that way --
    # the point of the JJ_CONFIG override is that pi no longer needs it. But
    # denying the key files alone would not have been enough: the agent socket
    # is what actually carries authority, and the forwarded agent holds the
    # auth keys (madhu-ssh-key, hetzner) alongside the signing one. An agent
    # cannot be made sign-only -- "sign this blob" is its only operation, and
    # ssh auth *is* signing a blob -- so anything that can sign a commit through
    # it can also authenticate as you. Strip the pointer instead.
    #
    # This holds up because the sandbox cannot recover the socket path by other
    # means: /tmp is not listable in there, and /proc/<pid>/environ for other
    # processes is denied. Both verified; if either regresses, so does this.
    environment.deny_vars = [ "SSH_AUTH_SOCK" ];
    environment.set_vars.JJ_CONFIG = "$HOME/${jjSandboxConfigDir}";
  };

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
    command = /home/madhu/.nix-profile/bin/zsh
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
    font-size = 12
    font-family = 0xProto Nerd Font Mono
    font-family = Symbols Nerd Font
    font-family = Noto Sans Symbols2
  '';

  # ── Zed ───────────────────────────────────────────────────────────────────

  home.file.".config/zed/settings.json".text = ''
    // Zed settings
    //
    // For information on how to configure Zed, see the Zed
    // documentation: https://zed.dev/docs/configuring-zed
    //
    // To see all of Zed's default settings without changing your
    // custom settings, run `zed: open default settings` from the
    // command palette (cmd-shift-p / ctrl-shift-p)
    {
      "terminal": {
        "font_family": "0xProto Nerd Font Mono"
      },
      "context_servers": {
        "serena-context-server": {
          "enabled": true,
          "remote": false,
          "settings": {
            "python_executable": null,
          },
        },
      },
      "agent_buffer_font_size": 18.0,
      "agent_ui_font_size": 18.0,
      "ui_font_family": ".ZedSans",
      "icon_theme": "Zed (Default)",
      "project_panel": {
        "dock": "left",
      },
      "outline_panel": {
        "dock": "left",
      },
      "collaboration_panel": {
        "dock": "left",
      },
      "git_panel": {
        "dock": "left",
      },
      "agent": {
        "tool_permissions": {
          "tools": {
            "search_web": {
              "default": "allow",
            },
          },
        },
        "dock": "right",
        "sidebar_side": "right",
        "default_model": {
          "effort": "high",
          "enable_thinking": true,
          "provider": "zed.dev",
          "model": "claude-sonnet-4-6",
        },
      },
      "telemetry": {
        "metrics": false,
        "diagnostics": false,
      },
      "ui_font_size": 18,
      "buffer_font_size": 18,
      "theme": {
        "mode": "system",
        "light": "Oolong",
        "dark": "Oolong",
      },
    }
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

    # Copy the starship-claude binary from the plugin cache to ~/.local/bin so
    # the statusLine command is available without relying on the cache path.
    # Runs after installStarshipClaude so the cache is populated first.
    installStarshipClaudeBinary = lib.hm.dag.entryAfter [ "writeBoundary" "installStarshipClaude" ] ''
      _bin=$(ls "${config.home.homeDirectory}/.claude/plugins/cache/starship-claude/starship-claude/"*/bin/starship-claude 2>/dev/null | head -1 || true)
      if [ -n "$_bin" ] && [ -f "$_bin" ]; then
        $DRY_RUN_CMD mkdir -p "${config.home.homeDirectory}/.local/bin"
        $DRY_RUN_CMD cp "$_bin" "${config.home.homeDirectory}/.local/bin/starship-claude"
        $DRY_RUN_CMD chmod +x "${config.home.homeDirectory}/.local/bin/starship-claude"
      fi
    '';

    # Write ~/.pi/agent/settings.json from Nix-managed values.
    # lastChangelogVersion is runtime state written by pi itself — preserved
    # from the existing file; everything else is overwritten from Nix.
    piSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      _piDir="${config.home.homeDirectory}/.pi/agent"
      _piSettings="$_piDir/settings.json"
      _piBase='${builtins.toJSON {
        defaultProvider = "anthropic";
        defaultModel = "claude-opus-5";
        defaultThinkingLevel = "xhigh";
        theme = "dark";
        npmCommand = [ "pnpm" "--ignore-workspace" ];
        enabledModels = [
          "anthropic/claude-sonnet-5"
          "anthropic/claude-opus-4-8"
          "anthropic/claude-opus-5"
          "openai-codex/gpt-5.6-sol"
          "openai-codex/gpt-5.6-terra"
          "openai-codex/gpt-5.6-luna"
        ];
        packages = [
          "npm:pi-subagents"
          "npm:pi-mcp-adapter"
          "npm:pi-web-access"
          "npm:@vigolium/piolium"
          "npm:@plannotator/pi-extension"
          "npm:remote-pi"
          "npm:pi-hermes-memory"
        ];
      }}'
      if [ -z "$DRY_RUN_CMD" ]; then
        mkdir -p "$_piDir"
        _piState=$(${pkgs.jq}/bin/jq -c \
          'if has("lastChangelogVersion") then {lastChangelogVersion} else {} end' \
          "$_piSettings" 2>/dev/null || echo '{}')
        echo "$_piBase" \
          | ${pkgs.jq}/bin/jq --argjson s "$_piState" '. + $s' \
          > "$_piSettings.tmp" && mv "$_piSettings.tmp" "$_piSettings"
      fi
    '';

    # Write ~/.claude/settings.json from Nix-managed values.
    # Runs after plugin activations (which may also write to settings.json) so
    # this is always the final authoritative write.
    # Permissions (allow/deny/ask) are runtime state — preserved from whatever
    # Claude Code has written; everything else is overwritten from Nix.
    claudeSettings = lib.hm.dag.entryAfter [
      "writeBoundary"
      "installStarshipClaude"
      "installGhosttyNotifications"
    ] ''
      _settings="${config.home.homeDirectory}/.claude/settings.json"
      _base='${builtins.toJSON {
        statusLine = {
          type    = "command";
          padding = 0;
          command = "~/.local/bin/starship-claude";
        };
        enabledPlugins = {
          "starship-claude@starship-claude"                = true;
          "ghostty-notifications@recursechat-agent-workflow" = true;
        };
        extraKnownMarketplaces = {
          "starship-claude" = {
            source = {
              source = "git";
              url    = "https://github.com/martinemde/starship-claude.git";
            };
          };
          "recursechat-agent-workflow" = {
            source = {
              source = "git";
              url    = "https://github.com/recursechat/agent-workflow.git";
            };
          };
        };
      }}'
      if [ -z "$DRY_RUN_CMD" ]; then
        _perms=$(${pkgs.jq}/bin/jq -c 'if has("permissions") then {permissions:.permissions} else {} end' \
          "$_settings" 2>/dev/null || echo '{}')
        echo "$_base" \
          | ${pkgs.jq}/bin/jq --argjson p "$_perms" '. + $p' \
          > "$_settings.tmp" && mv "$_settings.tmp" "$_settings"
      fi
    '';
  };
}
