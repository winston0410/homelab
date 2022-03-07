
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
