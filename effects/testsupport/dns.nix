/*
  A NixOS test module that provides a DNS server and configures it on all nodes.
*/
{ config, lib, ... }:
let

  inherit (lib)
    concatMapStringsSep
    mkOption types
    ;

  cfg = config.dns;

in
{

  options = {
    dns.nodeName = mkOption {
      description = ''
        The `<name>` in `nodes.<name>` for the DNS server.
      '';
      type = types.str;
      default = "dns";
    };
  };

  config = {

    nodes.${cfg.nodeName} = { nodes, pkgs, ... }: {
      networking.firewall.allowedUDPPorts = [ 53 ];
      services.bind.enable = true;
      services.bind.extraOptions = "empty-zones-enable no;";
      services.bind.zones = [{
        name = ".";
        master = true;
        file = pkgs.writeText "root.zone" ''
          $TTL 3600
          . IN SOA ${cfg.nodeName}. ${cfg.nodeName}. ( 1 8 2 4 1 )
          . IN NS ${cfg.nodeName}.
          ${concatMapStringsSep
            "\n"
            (node: "${node.networking.hostName}. IN A ${node.networking.primaryIPAddress}")
            (builtins.attrValues nodes)
          }
        '';
      }];
    };

    defaults = { nodes, ... }: {
      environment.etc."resolv.conf".text = ''
        nameserver ${nodes.${cfg.nodeName}.networking.primaryIPAddress}
      '';
    };

  };

}
