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
