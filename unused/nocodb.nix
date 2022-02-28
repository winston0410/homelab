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
    system.activationScripts.mkNocodbVolume = lib.stringAfter [ "var" ] ''
      mkdir -p /var/lib/nocodb
    '';

    system.activationScripts.mkNetwork = mkDockerNetwork {
      ip = "172.24.0.0/16";
      name = "nocodb";
    };

    services.nginx.virtualHosts.${secret.hostname.nocodb} = {
      # forceSSL = true;
      # enableACME = true;
      locations."/" = { proxyPass = "http://localhost:20000"; };
    };

    virtualisation.oci-containers.containers.nocodb = {
      image = "nocodb/nocodb:latest";
      environment = {
        DATABASE_URL = "postgres://postgres:password@172.24.0.3:5432/accent";
      };
      ports = [ "20000:8000" ];
      extraOptions = [ "--network=nocodb" ];
      dependsOn = [ "nocodb-postgres" ];
    };

    virtualisation.oci-containers.containers.nocodb-postgres = {
      image = "postgres:14.1";
      environment = {
        POSTGRES_DB = "nocodb";
        POSTGRES_USER = "postgres";
        POSTGRES_PASSWORD = "password";
      };
      volumes = [ "/var/lib/nocodb:/var/lib/postgresql/data" ];
      extraOptions = [ "--network=nocodb" "--ip=172.24.0.3" ];
    };
  })
