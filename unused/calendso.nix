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

    system.activationScripts.mkCalendsoVolume = lib.stringAfter [ "var" ] ''
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
      passwordFile = config.age.secrets.restic-repository-passwd.path;
    };
  })
