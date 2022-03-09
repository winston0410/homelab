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

    jyutping-tools = { url = "path:/home/hugosum/jyutping-tools"; };

    #NOTE Save secret locally
    secret = { url = "path:/home/hugosum/secret"; };
  };

  outputs = { self, nixpkgs, deploy-rs, remote-flake-template, flake-utils
    , life-builder, otp-server, secret, jyutping-tools, ... }:
    (nixpkgs.lib.attrsets.recursiveUpdate {
      nixosConfigurations = {
        netcup = let system = "x86_64-linux";
        in (nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            (remote-flake-template.nixosModule {
              email = "hugosum.dev@protonmail.com";
              sshKeys = [ secret.keys.id_ed25519 ];
            })
            remote-flake-template.nixosModules.secret
            "${nixpkgs}/nixos/modules/profiles/hardened.nix"
            ./hardware/netcup.nix
            # Actual definition apart from template configuration
            # ({ pkgs, config, lib, ... }: {
            # #FIXME Investigate why acme-certs doesn't work
            # #REF https://discourse.nixos.org/t/how-to-use-security-acme-certs-and-useacmehost-correctly/17208
            # security.acme.certs.${secret.hostname.acme} = {
            # webroot = "/var/lib/acme/acme-challenge/";
            # email = "hugosum.dev@protonmail.com";
            # extraDomainNames = [ secret.hostname.pwd ];
            # };
            # })
            ({ pkgs, config, lib, ... }: {
              #NOTE Use the latest kernel for wireguard module
              boot.kernelPackages = with pkgs; linuxPackages_latest;

              services.nginx.virtualHosts.${secret.hostname.pwd} = {
                forceSSL = true;
                enableACME = true;
                locations."/" = {
                  proxyPass = "http://localhost:30625";
                  proxyWebsockets = true;
                };
              };

              services.nginx.virtualHosts.${secret.hostname.pdf-service} = {
                forceSSL = true;
                enableACME = true;
                locations."/" = { proxyPass = "http://localhost:30628"; };
              };

              system.activationScripts.mkVwVolume = lib.stringAfter [ "var" ] ''
                mkdir -p /var/lib/vaultwarden
              '';

              virtualisation.oci-containers.containers.vw = {
                image = "vaultwarden/server:latest";
                ports = [ "30625:80" ];
                volumes = [ "/var/lib/vaultwarden/:/data/" ];
              };

              #TODO Use the correct password file
              age.secrets.restic-repository-passwd.file =
                ./.env/restic-repository-passwd.age;

              services.restic.backups.vaultwarden = {
                initialize = true;
                repository = "/tmp/backup/vaultwarden";
                paths = [ "/var/lib/vaultwarden" ];
                timerConfig = { OnCalendar = "daily"; };
                passwordFile = config.age.secrets.restic-repository-passwd.path;
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
                ports = [ "30628:3001" ];
              };

              networking.firewall.allowPing = lib.mkForce true;
            })
          ];
        });

        #NOTE Use for storing backup for netcup
        #NOTE oracle free tier may have inconsistent kernel modules behavior, check with 
        # lsmod | grep veth
        oracle1 = let system = "x86_64-linux";
        in (nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            (remote-flake-template.nixosModule {
              email = "hugosum.dev@protonmail.com";
              sshKeys = [ secret.keys.id_ed25519 ];
            })
            remote-flake-template.nixosModules.secret
            "${nixpkgs}/nixos/modules/profiles/hardened.nix"
            ./hardware/oracle1.nix
            ({ pkgs, config, lib, ... }: {
              boot.kernelPackages = with pkgs; linuxPackages_latest;
            })
            ({ pkgs, lib, config, ... }:
              {
                # services.nginx.virtualHosts.${secret.hostname.backup} = {
                # forceSSL = true;
                # locations."/" = { proxyPass = "http://localhost:20000"; };
                # };

                # system.activationScripts.mkBackupVolume =
                # lib.stringAfter [ "var" ] ''
                # mkdir -p /var/lib/backup
                # cp ${secret.keys.htpasswd} /var/lib/backup/.htpasswd
                # '';

                # services.nginx.virtualHosts.${secret.hostname.backup} = {
                # # forceSSL = true;
                # # enableACME = true;
                # locations."/" = { proxyPass = "http://localhost:20000"; };
                # };

                # #TODO How to get htpasswd binary in Nix?
                # virtualisation.oci-containers.containers.restic-server = {
                # image = "restic/rest-server:0.10.0";
                # ports = [ "20000:8000" ];
                # environment = { OPTIONS = "--append-only"; };
                # volumes = [ "/var/lib/backup:/data" ];
                # };
              })
          ];
        });

        oracle2 = let system = "x86_64-linux";
        in (nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            (remote-flake-template.nixosModule {
              email = "hugosum.dev@protonmail.com";
              sshKeys = [ secret.keys.id_ed25519 ];
            })
            remote-flake-template.nixosModules.secret
            "${nixpkgs}/nixos/modules/profiles/hardened.nix"
            ./hardware/oracle2.nix
            ({ pkgs, config, lib, ... }: {
              boot.kernelPackages = with pkgs; linuxPackages_latest;
            })
            ({ pkgs, config, lib, ... }: {
              #TODO reuse cert from rscantonese
              #REF https://nixos.org/manual/nixos/stable/index.html#module-security-acme-nginx

              services.nginx.virtualHosts.${secret.hostname.jyut.rscantonese} =
                {
                  locations."/" = { proxyPass = "http://localhost:8080"; };
                  forceSSL = true;
                  enableACME = true;
                };

              virtualisation.oci-containers.containers.jyutping-microservice = {
                image = "localhost/jyutping-microservice:latest";
                imageFile =
                  jyutping-tools.packages.${system}.jyutping-microservice-image;
                environment = { PRODUCTION = "1"; ALLOWED_ORIGIN = "https://jyut.info"; };
                environmentFiles = [ ];
                #REF https://github.com/containers/podman/issues/12370
                # Has to use --net=host in order to make the host machine resolve hostname correctly
                extraOptions = [ "--net=host" ];
                ports = [ "8080:8080" ];
              };

              # services.nginx.virtualHosts.${secret.hostname.jyut.ten-degrees} =
              # {
              # locations."/" = { proxyPass = "http://localhost:8081"; };
              # };

              # virtualisation.oci-containers.containers.auto-fetcher = {
              # image = "docker.io/winston0410/auto-fetcher:c787dfb";
              # environment = {
              # PORT = "8081";
              # };
              # extraOptions = [ "--net=host" ];
              # ports = [ "8081:8081" ];
              # };
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

      deploy.nodes.oracle1 = {
        hostname = secret.ip.oracle1;
        profiles.system = {
          sshUser = "root";
          path = deploy-rs.lib.x86_64-linux.activate.nixos
            self.nixosConfigurations.oracle1;
        };
        fastConnection = true;
      };

      deploy.nodes.oracle2 = {
        hostname = secret.ip.oracle2;
        profiles.system = {
          sshUser = "root";
          path = deploy-rs.lib.x86_64-linux.activate.nixos
            self.nixosConfigurations.oracle2;
        };
        fastConnection = true;
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
