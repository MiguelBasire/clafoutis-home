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
    # Media keys. brightnessctl goes through logind, so no udev rule or
    # setuid is needed.
    brightnessctl
    # What gnome-control-center's panels did under Regolith.
    pavucontrol
    networkmanagerapplet
  ];

  # XKB layouts, previously deployed by ~/.config/sway/install.sh.
  xdg.configFile."xkb/symbols" = {
    source = ./sway/xkb/symbols;
    recursive = true;
  };

  # Helper scripts, previously deployed by ~/.config/sway/install.sh.
  home.file = lib.genAttrs'
    [ "screenshot" "rescan-displays" "dock-diag" ]
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

      # Added on top of Home Manager's defaults (sway's stock i3-style set,
      # hjkl for focus/move). TODO: port Regolith's own bindings once
      # /etc/regolith has been copied somewhere readable — this draft only
      # carries over what lives in ~/.config/regolith3.
      keybindings = lib.mkOptionDefault {
        # Regolith habit: launcher on $mod+Space (displaces focus mode_toggle).
        "${mod}+space" = "exec fuzzel";
        "${mod}+Ctrl+Return" = "exec foot";
        "${mod}+Escape" = "exec /usr/bin/swaylock -f";

        # From 85-screenshot.
        "Print" = "exec ${bin}/screenshot screen";
        "Shift+Print" = "exec ${bin}/screenshot region";
        "${mod}+Print" = "exec ${bin}/screenshot window";
        "Ctrl+Print" = "exec ${bin}/screenshot all";
        "${mod}+Shift+Print" = "exec ${bin}/screenshot pick";

        # From 90-display-rescan.
        "${mod}+Shift+F5" = "exec ${bin}/rescan-displays";
        "${mod}+Ctrl+F5" = "exec ${bin}/rescan-displays --deep";

        # wpctl is the system PipeWire's (Ubuntu ships wireplumber).
        "XF86AudioRaiseVolume" = "exec wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+";
        "XF86AudioLowerVolume" = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
        "XF86AudioMute" = "exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        "XF86AudioMicMute" = "exec wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
        "XF86MonBrightnessUp" = "exec brightnessctl set 5%+";
        "XF86MonBrightnessDown" = "exec brightnessctl set 5%-";
      };

      startup = [
        # The system polkit agent (apt policykit-1-gnome): a Nix-built one
        # can't reach the host's setuid polkit-agent-helper-1. Silently does
        # nothing if that package isn't installed.
        { command = "/usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1"; }
        { command = "nm-applet --indicator"; }
      ];
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
