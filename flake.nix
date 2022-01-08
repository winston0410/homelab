{
  description = "Flake for deployment";

  inputs = {
    deploy-rs = { url = "github:serokell/deploy-rs"; };

    nixpkgs = { url = "github:nixos/nixpkgs/nixos-unstable"; };

    remote-flake-template = {
      url = "github:winston0410/remote-flake-template";
    };

    flake-utils = { url = "github:numtide/flake-utils"; };

    life-builder = { url = "github:winston0410/life-builder"; };

    otp-server = { url = "github:winston0410/otp-server"; };

    #NOTE Save secret locally
    secret = { url = "path:/home/hugosum/secret"; };
  };

  outputs = { self, nixpkgs, deploy-rs, remote-flake-template, flake-utils
    , life-builder, otp-server, secret, ... }:
    (nixpkgs.lib.attrsets.recursiveUpdate {
      nixosConfigurations = {
        netcup = let system = "x86_64-linux";
        in (nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            remote-flake-template.nixosModule
            remote-flake-template.nixosModules.secret
            "${nixpkgs}/nixos/modules/profiles/hardened.nix"
            ./hardware/netcup.nix
            # Actual definition apart from template configuration
            ({ pkgs, config, lib, ... }: {
              boot.kernelPackages = with pkgs; linuxPackages_5_14;

              environment.systemPackages = with pkgs; [ ];

              networking.firewall.allowedTCPPorts = [ 80 443 ];

              services.nginx.virtualHosts.${secret.hostname.pwd} = {
                forceSSL = true;
                enableACME = true;
                locations."/" = {
                  proxyPass = "http://localhost:30625";
                  proxyWebsockets = true;
                };
              };

              # Email server in docker
              #NOTE https://hub.docker.com/r/mailserver/docker-mailserver

              # For ecommerce
              #NOTE https://github.com/solidusio/solidus

              #NOTE https://hub.docker.com/r/valeriansaliou/vigil

              #NOTE https://hub.docker.com/r/linuxserver/wireguard

              #NOTE https://github.com/revoltchat

              #NOTE https://github.com/orhun/rustypaste

              #NOTE Set up backup repository with port forwarding local machine
              # services.restic.backups.vaultwarden = {
              # repository =
              # "rest:http://${secret.ip.midway}:44444/vaultwarden/";
              # initialize = true;
              # paths = [ "/var/lib/vaultwarden" ];
              # timerConfig = { onCalendar = "Monday 11:00"; };
              # passwordFile = "";
              # };

              # services.nginx.virtualHosts.${secret.hostname.otp} = {
              # forceSSL = true;
              # enableACME = true;
              # locations."/" = { proxyPass = "http://localhost:30624"; };
              # };

              services.nginx.virtualHosts.${secret.hostname.pdf-service} = {
                forceSSL = true;
                enableACME = true;
                locations."/" = { proxyPass = "http://localhost:30628"; };
              };

              # services.nginx.virtualHosts.${secret.hostname.music} = {
              # forceSSL = true;
              # enableACME = true;
              # locations."/" = { proxyPass = "http://localhost:30626"; };
              # };

              # services.nginx.virtualHosts.${secret.hostname.sso} = {
              # forceSSL = true;
              # enableACME = true;
              # locations."/" = { proxyPass = "http://localhost:30626"; };
              # };

              security.acme = { email = "hugosum.dev@protonmail.com"; };

              users.users.admin.openssh.authorizedKeys.keyFiles =
                [ secret.keys.id_ed25519 ];

              #NOTE Not in use
              # age.secrets.telegram-bot.file = ./.env/netcup/life-builder.age;
              
              # virtualisation.oci-containers.containers.telegram-bot = {
              # image = "localhost/telegram-bot:latest";
              # imageFile = life-builder.packages.${system}.image;
              # environmentFiles = [ config.age.secrets.telegram-bot.path ];
              # };

              #NOTE Not in use
              # age.secrets.otp-server.file = ./.env/netcup/otp-server.age;
              
              # virtualisation.oci-containers.containers.otp = {
              # image = "localhost/otp-server:latest";
              # imageFile = otp-server.packages.${system}.image;
              # environmentFiles = [ config.age.secrets.otp-server.path ];
              # ports = [ "30624:30624" ];
              # };

              system.activationScripts.mkVwVolume = lib.stringAfter [ "var" ] ''
                mkdir -p /var/lib/vaultwarden
              '';

              virtualisation.oci-containers.containers.vw = {
                image = "vaultwarden/server:latest";
                ports = [ "30625:80" ];
                volumes = [ "/var/lib/vaultwarden/:/data/" ];
              };

              system.activationScripts.mkMeiliSearchVolume =
                lib.stringAfter [ "var" ] ''
                  mkdir -p /var/lib/meilisearch.ms
                '';

              services.nginx.virtualHosts.${secret.hostname.search} = {
                forceSSL = true;
                enableACME = true;
                locations."/" = { proxyPass = "http://localhost:30627"; };
              };

              virtualisation.oci-containers.containers.search = {
                image = "getmeili/meilisearch:latest";
                ports = [ "30627:7700" ];
                environment = {
                  MEILI_NO_ANALYTICS = "true";
                  MEILI_ENV = "production";
                  MEILI_MASTER_KEY = "foobar";
                };
                volumes = [ "/var/lib/meilisearch.ms/:/data.ms/" ];
              };

              virtualisation.oci-containers.containers.pdf-service = {
                image = "winston0410/pdf-service:35713b9";
                # registry = "https://index.docker.io/v2/";
                ports = [ "30628:3001" ];
              };

              services.nginx.virtualHosts.${secret.hostname.accent} = {
                forceSSL = true;
                enableACME = true;
                locations."/" = { proxyPass = "http://localhost:30629"; };
              };

              # system.activationScripts.mkAccentVolume = lib.stringAfter [ "var" ] ''
              # mkdir -p /var/lib/accent
              # '';

              # system.activationScripts.mkAccent = let
              # docker = config.virtualisation.oci-containers.backend;
              # dockerBin = "${pkgs.${docker}}/bin/${docker}";
              # in ''
              # ${dockerBin} network inspect accent >/dev/null 2>&1 || ${dockerBin} network create accent --subnet 172.21.0.0/16
              # '';

              # virtualisation.oci-containers.containers.accent = {
              # image = "mirego/accent:v1.9.1";
              # ports = [ "30629:4000" ];
              # environment = {
              # PORT = 4000;
              # DATABASE_URL =
              # "postgres://postgres:password@postgresql:5432/accent_development";
              # DUMMY_LOGIN_ENABLED = true;
              # };
              # extraOptions = [ "--network=accent" ];
              # };

              virtualisation.oci-containers.containers.postgres = {
                image = "postgres:14.1";
                environment = {
                  POSTGRES_DB = "accent_development";
                  POSTGRES_PASSWORD = "password";
                };
                volumes = [ "/var/lib/accent:/var/lib/postgresql/data" ];
                extraOptions = [ "--network=accent" ];
              };

              system.activationScripts.mkWireguardVolume =
                lib.stringAfter [ "var" ] ''
                  mkdir -p /var/lib/wireguard
                  mkdir -p /etc/wireguard
                '';

              services.nginx.virtualHosts.${secret.hostname.wireguard} = {
                forceSSL = true;
                enableACME = true;
                locations."/" = { proxyPass = "http://localhost:30630"; };
              };

              virtualisation.oci-containers.containers.wireguard = {
                image = "linuxserver/wireguard:1.0.20210914";
                environment = {
                  TZ = "Europe/London";
                  SERVERURL = secret.hostname.wireguard;
                  SERVERPORT = "30630";
                  PEERS = "1";
                };
                ports = [ "51820:51820/udp" ];
                volumes = [
                  "/var/lib/wireguard:/lib/modules"
                  "/etc/wireguard:/config"
                ];
                extraOptions = [
                  "--cap-add=NET_ADMIN"
                  "--cap-add=SYS_MODULE"
                  "--sysctl='net.ipv4.conf.all.src_valid_mark=1'"
                ];
              };
            })
          ];
        });
      };

      deploy.nodes.netcup = {
        hostname = secret.ip.netcup;
        profiles.system = {
          #NOTE Has to deploy with root, as system is sudo-less
          sshUser = "root";
          path = deploy-rs.lib.x86_64-linux.activate.nixos
            self.nixosConfigurations.netcup;
        };
      };

      checks = builtins.mapAttrs
        (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

    } (flake-utils.lib.eachDefaultSystem (system: {
      devShell = (({ pkgs, ... }:
        pkgs.mkShell {
          shellHook = ''
            nix flake lock --update-input remote-flake-template;
            nix flake lock --update-input secret;
          '';
        }) { pkgs = nixpkgs.legacyPackages.${system}; });
    })));
}
