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

    jyutping-microservice = {
      url = "path:/home/hugosum/jyutping-tools/microservice";
    };

    #NOTE Save secret locally
    secret = { url = "path:/home/hugosum/secret"; };
  };

  outputs = { self, nixpkgs, deploy-rs, remote-flake-template, flake-utils
    , life-builder, otp-server, secret, jyutping-microservice, ... }:
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
            ({ pkgs, config, lib, ... }:
              {

                # services.nginx.virtualHosts.${secret.hostname.accent} = {
                # forceSSL = true;
                # enableACME = true;
                # locations."/" = { proxyPass = "http://localhost:30629"; };
                # };

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

                # virtualisation.oci-containers.containers.postgres = {
                # image = "postgres:14.1";
                # environment = {
                # POSTGRES_DB = "accent_development";
                # POSTGRES_PASSWORD = "password";
                # };
                # volumes = [ "/var/lib/accent:/var/lib/postgresql/data" ];
                # extraOptions = [ "--network=accent" ];
                # };
              })
            ({ pkgs, config, lib, ... }: {
                #FIXME Investigate why acme-certs doesn't work
                #REF https://discourse.nixos.org/t/how-to-use-security-acme-certs-and-useacmehost-correctly/17208
              security.acme.certs.${secret.hostname.acme} = {
                webroot = "/var/lib/acme/acme-challenge/";
                email = "hugosum.dev@protonmail.com";
                extraDomainNames = [ secret.hostname.pwd ];
              };
            })
            ({ pkgs, config, lib, ... }:
              let
                mkDockerNetwork = ip: name:
                  let
                    docker = config.virtualisation.oci-containers.backend;
                    dockerBin = "${pkgs.${docker}}/bin/${docker}";
                  in ''
                    ${dockerBin} network inspect ${name} >/dev/null 2>&1 || ${dockerBin} network create ${name} --subnet ${ip}
                  '';
              in {
                services.nginx.virtualHosts.${secret.hostname.booking} = {
                  forceSSL = true;
                  enableACME = true;
                  locations."/" = {
                    proxyPass = "http://localhost:40000";
                    proxyWebsockets = true;
                  };
                };

                system.activationScripts.mkCalendsoVolume =
                  lib.stringAfter [ "var" ] ''
                    mkdir -p /var/lib/calendso
                  '';

                system.activationScripts.mkCalendsoNetwork =
                  mkDockerNetwork "172.23.0.0/16" "calendso";

                age.secrets.calendso.file = ./.env/calendso.age;

                virtualisation.oci-containers.containers.calendso = {
                  image = "calendso/calendso:latest";
                  ports = [ "40000:3000" ];
                  environment = {
                    BASE_URL = "http://localhost:3000";
                    NEXT_PUBLIC_APP_URL = "http://localhost:3000";
                    # "postgres://$POSTGRES_USER:$POSTGRES_PASSWORD@172.23.0.2:5432/calendso";
                  };
                  environmentFiles = [ config.age.secrets.calendso.path ];
                  extraOptions = [ "--network=calendso" ];
                  dependsOn = [ "calendso-postgres" ];
                };

                virtualisation.oci-containers.containers.calendso-postgres = {
                  image = "postgres:14.1";
                  environmentFiles = [ config.age.secrets.calendso.path ];
                  volumes = [ "/var/lib/calendso:/var/lib/postgresql/data" ];
                  extraOptions = [ "--network=calendso" "--ip=172.23.0.2" ];
                };

                services.restic.backups.calendso = {
                  initialize = true;
                  repository = "/tmp/backup/calendso";
                  paths = [ "/var/lib/calendso" ];
                  timerConfig = { OnCalendar = "daily"; };
                  passwordFile =
                    config.age.secrets.restic-repository-passwd.path;
                };
              })
            ({ pkgs, config, lib, ... }: {
              #NOTE Use the latest kernel for wireguard module
              boot.kernelPackages = with pkgs; linuxPackages_latest;

              # Extra cert for using single domain name in multiple devices
              # security.acme.certs.${secret.hostname.acme} = {
              # email = "hugosum.dev@protonmail.com";
              # };

              services.nginx.virtualHosts.${secret.hostname.pwd} = {
                forceSSL = true;
                enableACME = true;
                # useACMEHost = secret.hostname.acme;
                locations."/" = {
                  proxyPass = "http://localhost:30625";
                  proxyWebsockets = true;
                };
              };

              #NOTE Set up backup with sftp with restic

              # Email server in docker
              #NOTE https://hub.docker.com/r/mailserver/docker-mailserver

              # For ecommerce
              #NOTE https://github.com/solidusio/solidus

              #NOTE https://hub.docker.com/r/valeriansaliou/vigil

              #NOTE https://hub.docker.com/r/linuxserver/wireguard

              #NOTE https://github.com/revoltchat

              #NOTE https://github.com/orhun/rustypaste

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
                # registry = "https://index.docker.io/v2/";
                ports = [ "30628:3001" ];
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
                  PUID = "0";
                  PGID = "0";
                };
                ports = [ "51820:51820/udp" ];
                volumes = [
                  "/var/lib/wireguard:/lib/modules"
                  "/etc/wireguard:/config"
                ];
                extraOptions = [
                  "--cap-add=NET_ADMIN"
                  "--cap-add=SYS_MODULE"
                  # "--sysctl='net.ipv4.conf.all.src_valid_mark=1'"
                ];
              };
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
              # services.nginx.virtualHosts.${secret.hostname.backup} = {
              # forceSSL = true;
              # locations."/" = { proxyPass = "http://localhost:20000"; };
              # };
            })
            ({ pkgs, lib, config, ... }: {
              system.activationScripts.mkBackupVolume =
                lib.stringAfter [ "var" ] ''
                  mkdir -p /var/lib/backup
                  cp ${secret.keys.htpasswd} /var/lib/backup/.htpasswd
                '';

              services.nginx.virtualHosts.${secret.hostname.backup} = {
                # forceSSL = true;
                # enableACME = true;
                locations."/" = { proxyPass = "http://localhost:20000"; };
              };

              #TODO How to get htpasswd binary in Nix?
              virtualisation.oci-containers.containers.restic-server = {
                image = "restic/rest-server:0.10.0";
                ports = [ "20000:8000" ];
                environment = { OPTIONS = "--append-only"; };
                volumes = [ "/var/lib/backup:/data" ];
              };
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
            ({ pkgs, lib, config, ... }:
              let
                mkDockerNetwork = { ip, name }:
                  let
                    docker = config.virtualisation.oci-containers.backend;
                    dockerBin = "${pkgs.${docker}}/bin/${docker}";
                  in ''
                    ${dockerBin} network inspect ${name} >/dev/null 2>&1 || ${dockerBin} network create ${name} --subnet ${ip}
                  '';
              in {
                # system.activationScripts.mkNocodbVolume =
                # lib.stringAfter [ "var" ] ''
                # mkdir -p /var/lib/nocodb
                # '';

                # system.activationScripts.mkNetwork = mkDockerNetwork {
                # ip = "172.24.0.0/16";
                # name = "nocodb";
                # };

                # services.nginx.virtualHosts.${secret.hostname.nocodb} = {
                # forceSSL = true;
                # enableACME = true;
                # locations."/" = { proxyPass = "http://localhost:8000"; };
                # };

                # virtualisation.oci-containers.containers.nocodb = {
                # image = "nocodb/nocodb:latest";
                # environment = {
                # DATABASE_URL =
                # "postgres://postgres:password@172.24.0.3:5432/accent";
                # };
                # ports = [ "8000:8000" ];
                # extraOptions = [ "--network=nocodb" ];
                # dependsOn = [ "nocodb-postgres" ];
                # };

                # virtualisation.oci-containers.containers.nocodb-postgres = {
                # image = "postgres:14.1";
                # environment = {
                # POSTGRES_DB = "nocodb";
                # POSTGRES_USER = "postgres";
                # POSTGRES_PASSWORD = "password";
                # };
                # volumes = [ "/var/lib/nocodb:/var/lib/postgresql/data" ];
                # extraOptions = [ "--network=nocodb" "--ip=172.24.0.3" ];
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
