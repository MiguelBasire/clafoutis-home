# Plain sway, no Regolith — the desktop layer as a Home Manager module.
#
# Imported ONLY by the "hmtest@clafoutis02" configuration for now: a
# throwaway, no-sudo test user used to reach parity with the Regolith session
# on real hardware before anything changes for miguel. See "Testing a
# Regolith-free desktop" in README.md. miguel@clafoutis02 keeps the scope
# boundary described in linux.nix until this is promoted.
#
# Split of responsibilities on this Ubuntu (non-NixOS) machine:
#   - the system (apt) keeps the sway and swaylock binaries, plus the portal,
#     polkit and keyring daemons. sway needs the host's GPU stack and swaylock
#     needs the host's PAM, which Nix-built copies can't use reliably here —
#     hence the `package = null`s below, which make Home Manager write the
#     config only.
#   - Home Manager owns every config file, and the user-level programs that
#     need neither GPU nor PAM (waybar, fuzzel, mako, kanshi, swayidle,
#     grimshot and friends).
{ config, lib, pkgs, ... }:

let
  mod = "Mod4";

  # Nord, to match kitty (linux.nix) and the regolith-look "nord" this
  # replaces.
  nord = {
    bg = "#2e3440";
    bg1 = "#3b4252";
    bg2 = "#434c5e";
    bg3 = "#4c566a";
    fg = "#eceff4";
    frost = "#88c0d0";
    blue = "#81a1c1";
    red = "#bf616a";
  };

  bin = "${config.home.homeDirectory}/.local/bin";

  # The internal eDP panel reports no EDID make/model/serial, so kanshi sees
  # it as this literal description.
  laptop = "Unknown Unknown Unknown";

  # Ported verbatim from ~/.config/regolith3/kanshi/profiles/*. The laptop
  # panel is 2880x1800@120Hz in every profile; only scale and position vary.
  panel = scale: position: {
    criteria = laptop;
    mode = "2880x1800@120Hz";
    inherit scale position;
  };
  monitor = criteria: mode: position: {
    inherit criteria mode position;
    scale = 1.0;
  };
  p2720dcA = "Dell Inc. DELL P2720DC 4S5JT03";
  p2720dcB = "Dell Inc. DELL P2720DC CVLHT03";
  s2721hsA = "Dell Inc. DELL S2721HS BGY83H3";
  s2721hsB = "Dell Inc. DELL S2721HS HGY83H3";
  # The trailing spaces are part of the name this monitor reports.
  mateview = "Huawei Technologies Co., Inc. MateView"
    + lib.concatStrings (lib.replicate 14 " ");
  philips = "Philips Consumer Electronics Company PHL 242S1 UHB2252003701";

  profile = name: outputs: {
    profile = {
      inherit name;
      outputs = map (o: o // { status = "enable"; }) outputs;
    };
  };

  # Keybindings: a port of Regolith 3.4's /usr/share/regolith/{common,sway}/
  # config.d partials (snapshot in ~/.config/regolith-snapshot), with the
  # Regolith-only programs swapped for plain equivalents — the comment on
  # each group names the partial it comes from. This *replaces* Home
  # Manager's i3-style defaults rather than extending them: those put layout
  # commands on $mod+w/b/d/e/s, which Regolith uses for settings.

  # Workspace n (1-19) is on key n for 1-9, 0 for 10, Ctrl + 1-9 for 11-19
  # (Regolith's wm.workspace.NN.key / $ws_high_key).
  workspaces =
    lib.imap1 (n: key: { inherit n key; }) [ "1" "2" "3" "4" "5" "6" "7" "8" "9" "0" ]
    ++ lib.imap1 (n: key: { n = n + 10; key = "Ctrl+${key}"; })
      [ "1" "2" "3" "4" "5" "6" "7" "8" "9" ];
  # common/40_workspace-config: go / move window (Shift) / carry window (Alt).
  workspaceKeys = lib.listToAttrs (lib.concatMap
    ({ n, key }:
      let ws = "workspace number ${toString n}"; in [
        (lib.nameValuePair "${mod}+${key}" ws)
        (lib.nameValuePair "${mod}+Shift+${key}" "move container to ${ws}")
        (lib.nameValuePair "${mod}+Mod1+${key}" "move container to ${ws}; ${ws}")
      ])
    workspaces);

  # focus/move/resize in all four directions, on both hjkl and the arrows.
  dirs = {
    left = [ "h" "Left" ];
    down = [ "j" "Down" ];
    up = [ "k" "Up" ];
    right = [ "l" "Right" ];
  };
  directionalKeys = lib.concatMapAttrs (dir: keys: lib.listToAttrs (lib.concatMap
    (k: [
      (lib.nameValuePair "${mod}+${k}" "focus ${dir}")
      (lib.nameValuePair "${mod}+Shift+${k}" "move ${dir}")
      (lib.nameValuePair "${mod}+Ctrl+Shift+${k}" "move workspace to output ${dir}")
    ])
    keys)) dirs;

  keys = workspaceKeys // directionalKeys // {
    # common/15_base_launchers (+ the terminal override in
    # ~/.config/regolith3/common-wm). systemd-run gives each app its own
    # scope, as Regolith does.
    "${mod}+Return" = "exec systemd-run --user --scope kitty";
    "${mod}+Shift+Return" =
      "exec systemd-run --user --scope gtk-launch $(xdg-settings get default-web-browser)";
    # Not in Regolith: a terminal that works without the GPU setup.
    "${mod}+Ctrl+Return" = "exec foot";

    # common/30_navigation.
    "${mod}+a" = "focus parent";
    "${mod}+z" = "focus child";
    "${mod}+Tab" = "workspace next";
    "${mod}+Mod1+Right" = "workspace next";
    "${mod}+Ctrl+Tab" = "workspace next_on_output";
    "${mod}+Ctrl+l" = "workspace next_on_output";
    "${mod}+Shift+Tab" = "workspace prev";
    "${mod}+Mod1+Left" = "workspace prev";
    "${mod}+Ctrl+Shift+Tab" = "workspace prev_on_output";
    "${mod}+Ctrl+h" = "workspace prev_on_output";
    "${mod}+Ctrl+a" = "scratchpad show";

    # common/40_i3-swap-focus: last focused window. swayr stands in for
    # i3-swap-focus, which is Regolith-only.
    "${mod}+period" = "exec swayr switch-to-urgent-or-lru-window";

    # common/40_workspace-config (non-workspace part).
    "${mod}+v" = "split vertical";
    "${mod}+g" = "split horizontal";
    "${mod}+BackSpace" = "split toggle";
    "${mod}+f" = "fullscreen toggle";
    "${mod}+Shift+f" = "floating toggle";
    "${mod}+Ctrl+m" = "move to scratchpad";
    "${mod}+Shift+t" = "focus mode_toggle";
    "${mod}+t" = "layout toggle tabbed stacking splith splitv";

    # common/50_resize-mode.
    "${mod}+r" = ''mode "Resize Mode"'';

    # common/82_rofication-ilia: the notification viewer becomes "bring
    # back the last dismissed notification" — mako keeps no browsable list.
    "${mod}+n" = "exec makoctl restore";

    # sway/20_ilia, with fuzzel and swayr in place of ilia. The look
    # selector ($mod+Alt+l) has no equivalent outside Regolith.
    "${mod}+space" = "exec fuzzel";
    "${mod}+Shift+space" = "exec fuzzel --list-executables-in-path";
    "${mod}+Ctrl+space" = "exec swayr switch-window";
    "${mod}+Mod1+space" = "exec ${bin}/file-search";

    # sway/30_keyboard_layout. Only does something for a keyboard with more
    # than one layout; every device here has exactly one.
    "${mod}+Mod1+BackSpace" = "input * xkb_switch_layout next";
    "${mod}+Mod1+Shift+BackSpace" = "input * xkb_switch_layout prev";

    # sway/35_gaps — moved off Regolith's minus/plus keysyms: on
    # fr_azerty_num `minus` is Shift+6, so $mod+minus would shadow
    # $mod+Shift+6 (move to workspace 6). The = key carries `=` and `+` on
    # both layouts here, so shrink is $mod+= and grow $mod+Shift+=; Ctrl
    # makes the step big.
    "${mod}+equal" = "gaps inner current minus 6";
    "${mod}+plus" = "gaps inner current plus 6";
    "${mod}+Ctrl+equal" = "gaps inner current minus 12";
    "${mod}+Ctrl+plus" = "gaps inner current plus 12";

    # sway/40_childe, via a stand-in script with the same flags.
    "${mod}+grave" = "exec ${bin}/next-free-workspace";
    "${mod}+Shift+grave" = "exec ${bin}/next-free-workspace --move-window";
    "${mod}+Mod1+grave" = "exec ${bin}/next-free-workspace --move-window --follow";

    # sway/42_gtklock, with the system swaylock (see programs.swaylock).
    "${mod}+Escape" = "exec /usr/bin/swaylock -f";

    # sway/55_session_keybindings. gnome-session-quit and regolith-look are
    # gone without the Regolith session: logout is `swaymsg exit`,
    # reboot/poweroff go straight to systemd, and "refresh session" restarts
    # the user services that replaced Regolith's.
    "${mod}+Shift+q" = ''[con_id="__focused__"] kill'';
    "${mod}+Mod1+q" =
      "exec kill -9 $(swaymsg -t get_tree | jq '.. | select(.focused? == true) | .pid')";
    "${mod}+Shift+c" = "reload";
    "${mod}+Shift+r" =
      "exec systemctl --user restart waybar.service kanshi.service swayrd.service";
    "${mod}+Shift+e" =
      "exec swaynag -t warning -m 'Do you really want to logout?' -b 'Logout' 'swaymsg exit'";
    "${mod}+Shift+b" =
      "exec swaynag -t warning -m 'Do you really want to reboot your system?' -b 'Reboot' 'systemctl reboot'";
    "${mod}+Shift+p" =
      "exec swaynag -t warning -m 'Do you really want to shutdown' -b 'Shutdown' 'systemctl poweroff'";
    "--locked ${mod}+Shift+s" = "exec systemctl suspend";

    # sway/60_config_keybindings. regolith-control-center goes with
    # Regolith; GNOME's control center only runs if it thinks it is in GNOME,
    # and the specific panels get standalone tools.
    "${mod}+c" = "exec env XDG_CURRENT_DESKTOP=GNOME gnome-control-center";
    "${mod}+d" = "exec wdisplays";
    "${mod}+w" = "exec nm-connection-editor";
    "${mod}+b" = "exec blueman-manager";
    "${mod}+Shift+n" = "exec /usr/bin/nautilus --new-window";

    # sway/65_media_keybindings — avizo (volumectl/lightctl and their
    # on-screen display) is in nixpkgs, so these are unchanged. The two
    # keycode bindings (play-pause, play) are in extraConfig.
    "--locked XF86AudioRaiseVolume" = "exec volumectl -u + 5";
    "--locked XF86AudioLowerVolume" = "exec volumectl -u - 5";
    "--locked XF86AudioMute" = "exec volumectl %";
    "--locked XF86AudioMicMute" = "exec volumectl -m %";
    "XF86MonBrightnessUp" = "exec lightctl + 5";
    "XF86MonBrightnessDown" = "exec lightctl - 5";
    "--locked XF86AudioPause" = "exec playerctl pause";
    "--locked XF86AudioNext" = "exec playerctl next";
    "--locked XF86AudioPrev" = "exec playerctl previous";

    # sway/70_bar_i3status-rs: `bar mode toggle` only drives swaybar;
    # waybar toggles itself on SIGUSR1.
    "${mod}+i" = "exec pkill -USR1 waybar";

    # Screenshots. Regolith's sway/80_grimshot bound $mod+Print and
    # $mod+Shift+Print too, but ~/.config/regolith3's 85-screenshot
    # overrode both, so only its all-screens binding survives here.
    "Print" = "exec ${bin}/screenshot screen";
    "Shift+Print" = "exec ${bin}/screenshot region";
    "${mod}+Print" = "exec ${bin}/screenshot window";
    "Ctrl+Print" = "exec ${bin}/screenshot all";
    "${mod}+Shift+Print" = "exec ${bin}/screenshot pick";
    "${mod}+Shift+Ctrl+Print" = "exec grimshot --notify save screen";

    # From ~/.config/regolith3's 90-display-rescan.
    "${mod}+Shift+F5" = "exec ${bin}/rescan-displays";
    "${mod}+Ctrl+F5" = "exec ${bin}/rescan-displays --deep";
  };

  # Stand-in for ilia's keybinding viewer ($mod+?): Regolith builds it from
  # the `## Category // Action // Keys ##` comments, which Home Manager's
  # generated config doesn't have — so list the bindings themselves.
  cheatsheet =
    let
      pretty = s: builtins.replaceStrings
        [ "Mod4" "Mod1" "--locked " ] [ "Super" "Alt" "" ] s;
      lines = lib.mapAttrsToList
        (key: cmd: "${pretty key}    ${lib.removePrefix "exec " cmd}")
        keys;
    in
    pkgs.writeShellScript "sway-keybindings" ''
      fuzzel --dmenu --width 90 --lines 30 --prompt 'keys: ' \
        < ${pkgs.writeText "sway-keybindings.txt" (lib.concatLines lines)} >/dev/null
    '';
in
{
  # Nix-built GUI programs need the host's GPU drivers — kitty in particular,
  # since programs.kitty (common.nix) installs it from nixpkgs. This exposes
  # them at /run/opengl-driver. It needs a one-time root step, which
  # activation keeps printing (with the full store path) until it is done:
  #
  #   sudo /nix/store/…-non-nixos-gpu-setup/bin/non-nixos-gpu-setup
  #
  # Until then kitty won't start; foot ($mod+Ctrl+Return) needs no GPU.
  targets.genericLinux.enable = true;

  home.packages = with pkgs; [
    # Fallback terminal: software-rendered, so it works before the GPU setup
    # above and whenever kitty misbehaves.
    foot
    # sway/bin/screenshot: grimshot and its own dependencies.
    sway-contrib.grimshot
    grim
    slurp
    wl-clipboard
    jq
    libnotify
    # Media keys: avizo is Regolith's own volume/brightness OSD, and its
    # volumectl/lightctl call pamixer/brightnessctl from PATH. brightnessctl
    # goes through logind, so no udev rule or setuid is needed.
    avizo
    pamixer
    brightnessctl
    playerctl
    # What regolith-control-center's panels did ($mod+d/w/b), plus a mixer.
    wdisplays
    networkmanagerapplet
    blueman
    pavucontrol
  ];

  # XKB layouts, previously deployed by ~/.config/sway/install.sh.
  xdg.configFile."xkb/symbols" = {
    source = ./sway/xkb/symbols;
    recursive = true;
  };

  # Helper scripts, previously deployed by ~/.config/sway/install.sh.
  home.file = lib.genAttrs'
    [ "screenshot" "rescan-displays" "dock-diag" "next-free-workspace" "file-search" ]
    (name: lib.nameValuePair ".local/bin/${name}" {
      source = ./sway/bin + "/${name}";
      executable = true;
    });

  wayland.windowManager.sway = {
    enable = true;
    # Use the system /usr/bin/sway (see the header).
    package = null;
    # Validation runs the sway binary, so it needs a non-null package.
    # Validate by hand instead: `sway --validate -c result/home-files/.config/sway/config`.
    checkConfig = false;
    # Starts sway-session.target, which waybar, mako, kanshi and swayidle
    # hang off as systemd user services.
    systemd.enable = true;

    config = {
      modifier = mod;
      terminal = "kitty";
      menu = "fuzzel";
      # waybar runs as a systemd user service instead (programs.waybar).
      bars = [ ];

      fonts = {
        names = [ "Monoid Nerd Font" ];
        size = 10.0;
      };

      # Ported from 95-keyboard-layout. Sway merges input blocks by
      # specificity, so the named devices win over the type:keyboard default.
      input = {
        "type:keyboard".xkb_layout = "fr_azerty_num";
        "1133:50504:Logitech_USB_Receiver".xkb_layout = "us_qwerty-fr";
        "1452:591:BY_Tech_Air75".xkb_layout = "us_qwerty-fr";
      };

      # Solid colour: the Regolith wallpaper is a GNOME slideshow XML, which
      # swaybg can't read.
      output."*".bg = "${nord.bg} solid_color";

      # wm.window.border.size / wm.floatingwindow.border.size were 0 in
      # ~/.config/regolith3/Xresources.
      window = {
        border = 0;
        titlebar = false;
        # sway/40_default-style.
        hideEdgeBorders = "smart";
        commands = [
          {
            criteria.title = ".*";
            command = "border pixel 0";
          }
          {
            criteria.class = "floating_window";
            command = "floating enable";
          }
        ];
      };
      floating = {
        border = 0;
        titlebar = false;
      };

      colors = {
        focused = {
          border = nord.frost;
          background = nord.frost;
          text = nord.bg;
          indicator = nord.blue;
          childBorder = nord.frost;
        };
        focusedInactive = {
          border = nord.bg2;
          background = nord.bg2;
          text = nord.fg;
          indicator = nord.bg2;
          childBorder = nord.bg2;
        };
        unfocused = {
          border = nord.bg1;
          background = nord.bg1;
          text = nord.fg;
          indicator = nord.bg1;
          childBorder = nord.bg1;
        };
        urgent = {
          border = nord.red;
          background = nord.red;
          text = nord.fg;
          indicator = nord.red;
          childBorder = nord.red;
        };
      };

      # The Regolith port (see `keys` above), plus its keybinding viewer.
      keybindings = keys // {
        "${mod}+question" = "exec ${cheatsheet}";
      };

      # common/50_resize-mode. Note hjkl don't mirror the arrows vertically
      # (k grows, j shrinks) — that is Regolith's own mapping, kept as is.
      modes."Resize Mode" =
        let
          small = "6 px or 6 ppt";
          large = "24 px or 24 ppt";
        in
        {
          "Left" = "resize shrink width ${small}";
          "Down" = "resize grow height ${small}";
          "Up" = "resize shrink height ${small}";
          "Right" = "resize grow width ${small}";
          "Shift+Left" = "resize shrink width ${large}";
          "Shift+Down" = "resize grow height ${large}";
          "Shift+Up" = "resize shrink height ${large}";
          "Shift+Right" = "resize grow width ${large}";
          "h" = "resize shrink width ${small}";
          "k" = "resize grow height ${small}";
          "j" = "resize shrink height ${small}";
          "l" = "resize grow width ${small}";
          "Shift+h" = "resize shrink width ${large}";
          "Shift+k" = "resize grow height ${large}";
          "Shift+j" = "resize shrink height ${large}";
          "Shift+l" = "resize grow width ${large}";
          "Return" = ''mode "default"'';
          "Escape" = ''mode "default"'';
          "${mod}+r" = ''mode "default"'';
        };

      # sway/35_gaps.
      gaps = {
        inner = 5;
        outer = 0;
        smartGaps = true;
      };

      # sway/40_default-style (borders are with `window`, above).
      focus.followMouse = false;
      workspaceAutoBackAndForth = false;

      startup = [
        # sway/85_polkit ran `mate-polkit`. A Nix-built agent can't reach the
        # host's setuid polkit-agent-helper-1, so start whichever system
        # agent is installed.
        {
          command = "sh -c 'for a in /usr/libexec/polkit-mate-authentication-agent-1 /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1; do [ -x \"$a\" ] && exec \"$a\"; done'";
        }
        # common/88_network-manager. --indicator: waybar's tray only speaks
        # StatusNotifierItem.
        { command = "nm-applet --indicator"; }
        # sway/65_media_keybindings: the OSD daemon and playerctl's
        # "last active player" tracker.
        { command = "avizo-service"; }
        { command = "playerctld daemon"; }
        # sway/25_xdg_desktop_portal.
        { command = "systemctl --user start xdg-desktop-portal.service"; }
      ];
    };

    extraConfig = ''
      # sway/65_media_keybindings: keycodes, as Regolith has them.
      bindcode --locked 172 exec playerctl play-pause
      bindcode --locked 208 exec playerctl play

      # sway/40_default-style.
      floating_maximum_size -1 x -1
      popup_during_fullscreen smart

      # sway/86_unclutter.
      seat * hide_cursor 5000
      seat * hide_cursor when-typing enable

      # sway/96_clamshell ran regolith-sway-clamshell; this is its plain
      # equivalent: panel off with the lid, back on when it opens. With no
      # external screen, logind suspends on lid close anyway.
      bindswitch --locked --reload lid:on output "${laptop}" disable
      bindswitch --locked --reload lid:off output "${laptop}" enable
    '';
  };

  # Backs $mod+period (last focused window) and $mod+Ctrl+space (window by
  # name), which Regolith did with i3-swap-focus and ilia.
  programs.swayr = {
    enable = true;
    systemd.enable = true;
    settings = {
      menu = {
        executable = "fuzzel";
        args = [ "--dmenu" "--prompt={prompt}: " ];
      };
      # Plain text: fuzzel doesn't render the pango markup in swayr's
      # default formats.
      format = {
        html_escape = false;
        urgency_start = "";
        urgency_end = "";
        window_format = "{indent}{app_name} — {title}";
        workspace_format = "{indent}workspace {name}";
        container_format = "{indent}container {layout}";
      };
    };
  };

  # Config only: the binary must be the distro's, since it authenticates
  # through the host's PAM (see programs.swaylock's own description).
  programs.swaylock = {
    enable = true;
    package = null;
    settings = {
      color = lib.removePrefix "#" nord.bg;
      show-failed-attempts = true;
      indicator-caps-lock = true;
    };
  };

  # Absolute /usr/bin paths: the service's PATH holds only bash.
  services.swayidle = {
    enable = true;
    timeouts = [
      {
        timeout = 300;
        command = "/usr/bin/swaylock -f";
      }
      {
        timeout = 600;
        command = "/usr/bin/swaymsg 'output * power off'";
        resumeCommand = "/usr/bin/swaymsg 'output * power on'";
      }
    ];
    events.before-sleep = "/usr/bin/swaylock -f";
  };

  services.kanshi = {
    enable = true;
    settings = [
      (profile "laptop" [ (panel 1.25 "0,0") ])
      (profile "p2720dc-pair" [
        (monitor p2720dcB "2560x1440@59.951Hz" "0,0")
        (panel 1.25 "0,1440")
        (monitor p2720dcA "2560x1440@59.951Hz" "2560,0")
      ])
      (profile "p2720dc-a" [
        (panel 1.25 "0,1440")
        (monitor p2720dcA "2560x1440@59.951Hz" "0,0")
      ])
      (profile "p2720dc-b" [
        (monitor p2720dcB "2560x1440@59.951Hz" "0,0")
        (panel 1.25 "0,1440")
      ])
      (profile "s2721hs-pair" [
        (monitor s2721hsA "1920x1080@60Hz" "0,0")
        (panel 1.5 "1017,1080")
        (monitor s2721hsB "1920x1080@60Hz" "1920,0")
      ])
      (profile "s2721hs-b" [
        (monitor s2721hsB "1920x1080@60Hz" "0,0")
        (panel 2.0 "0,1080")
      ])
      (profile "mateview" [
        (panel 1.25 "0,737")
        (monitor mateview "3840x2560@59.984Hz" "2304,0")
      ])
      (profile "philips" [
        (panel 1.5 "0,1080")
        (monitor philips "1920x1080@60Hz" "0,0")
      ])
    ];
  };

  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "Monoid Nerd Font:size=11";
        terminal = "kitty";
      };
      colors = {
        background = "2e3440f2";
        text = "eceff4ff";
        match = "88c0d0ff";
        selection = "434c5eff";
        selection-text = "eceff4ff";
        border = "88c0d0ff";
      };
    };
  };

  services.mako = {
    enable = true;
    settings = {
      font = "Monoid Nerd Font 10";
      background-color = nord.bg;
      text-color = nord.fg;
      border-color = nord.frost;
      default-timeout = 5000;
    };
  };

  # Top, as wm.bar.position was in Xresources.
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    settings.main = {
      layer = "top";
      position = "top";
      height = 24;
      modules-left = [ "sway/workspaces" "sway/mode" ];
      modules-center = [ "sway/window" ];
      modules-right = [ "cpu" "memory" "pulseaudio" "network" "battery" "clock" "tray" ];
      cpu.format = " {usage}%";
      memory.format = "󰍛 {percentage}%";
      pulseaudio = {
        format = "{icon} {volume}%";
        format-muted = "󰖁 muted";
        format-icons.default = [ "" "" "" ];
        on-click = "pavucontrol";
      };
      network = {
        format-wifi = " {essid}";
        format-ethernet = "󰈀 {ifname}";
        format-disconnected = "󰖪 offline";
      };
      battery = {
        format = "{icon} {capacity}%";
        format-charging = "󰂄 {capacity}%";
        format-icons = [ "" "" "" "" "" ];
        states = {
          warning = 25;
          critical = 10;
        };
      };
      clock.format = "{:%a %d %b  %H:%M}";
      tray.spacing = 8;
    };
    style = ''
      * {
        font-family: "Monoid Nerd Font";
        font-size: 12px;
      }
      window#waybar {
        background: ${nord.bg};
        color: ${nord.fg};
      }
      #workspaces button {
        padding: 0 6px;
        color: ${nord.fg};
      }
      #workspaces button.focused {
        background: ${nord.bg2};
        border-bottom: 2px solid ${nord.frost};
      }
      #workspaces button.urgent {
        background: ${nord.red};
      }
      #cpu, #memory, #pulseaudio, #network, #battery, #clock, #tray {
        padding: 0 8px;
      }
      #battery.warning { color: #ebcb8b; }
      #battery.critical { color: ${nord.red}; }
    '';
  };
}
