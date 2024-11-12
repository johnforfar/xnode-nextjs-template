{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.secure-hello-world;
  secure-hello-world = pkgs.callPackage ./package.nix { };
  isDevelopment = builtins.elem config.networking.hostName [
    "Johns-MacBook-Pro-2.local"  # Replace with your local machine's hostname
  ];
in
{
  options = {
    services.secure-hello-world = {
      enable = lib.mkEnableOption "Enable the secure nextjs app";

      hostname = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0";
        description = ''
          The hostname under which the app should be accessible.
        '';
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 3000;
        description = ''
          The port under which the app should be accessible.
        '';
      };

      domain = lib.mkOption {
        type = lib.types.str;
        default = "hello.johnforfar.com";
        description = ''
          The domain name under which the app will be served for production.
        '';
      };

      email = lib.mkOption {
        type = lib.types.str;
        default = "hello@example.com";  # Replace with your email
        description = ''
          Email address for Let's Encrypt notifications.
        '';
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to open ports in the firewall for this application.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.secure-hello-world = {
      wantedBy = [ "multi-user.target" ];
      description = "Nextjs App.";
      after = [ "network.target" ];
      environment = {
        HOSTNAME = cfg.hostname;
        PORT = toString cfg.port;
        NODE_ENV = if isDevelopment then "development" else "production";
      };
      serviceConfig = {
        ExecStart = "${lib.getExe secure-hello-world}";
        DynamicUser = true;
        CacheDirectory = "nextjs-app";
        Restart = "always";
        RestartSec = "10";
      };
    };

    # Only enable nginx in production
    services.nginx = lib.mkIf (!isDevelopment) {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;

      virtualHosts.${cfg.domain} = {
        enableACME = true;
        forceSSL = true;
        
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.port}";
          proxyWebsockets = true;
        };
      };
    };

    # Enable ACME/Let's Encrypt for production
    security.acme = lib.mkIf (!isDevelopment) {
      acceptTerms = true;
      defaults.email = cfg.email;
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = if isDevelopment
        then [ cfg.port ]
        else [ 80 443 cfg.port ];
    };
  };
}