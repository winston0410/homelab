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

              #NOTE Set up backup repository with port forwarding local machine
              # services.restic.backups.vaultwarden = {
              # repository =
              # "rest:http://${secret.ip.midway}:44444/vaultwarden/";
              # initialize = true;
              # paths = [ "/var/lib/vaultwarden" ];
              # timerConfig = { onCalendar = "Monday 11:00"; };
              # passwordFile = "";
              # };

              services.nginx.virtualHosts.${secret.hostname.otp} = {
                forceSSL = true;
                enableACME = true;
                locations."/" = { proxyPass = "http://localhost:30624"; };
              };
              
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

              age.secrets = {
                telegram-bot.file = ./.env/netcup/life-builder.age;
                otp-server.file = ./.env/netcup/otp-server.age;
              };

              #NOTE Not in use
              # virtualisation.oci-containers.containers.telegram-bot = {
                # image = "localhost/telegram-bot:latest";
                # imageFile = life-builder.packages.${system}.image;
                # environmentFiles = [ config.age.secrets.telegram-bot.path ];
              # };

              #NOTE Not in use
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
