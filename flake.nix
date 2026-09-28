{
  description = "Zero-Touch Techlab fleet Enroller ISO";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    disko.url = "github:nix-community/disko";
    # Add sextant/comin inputs based on their flake documentation
    comin.url = "github:nlewo/comin";
    # 1. Add the Sextant repository as an input
    sextant.url = "git+https://codeberg.org/DAWO/DAWO-Sextant.git";
  };

  outputs = { self, nixpkgs, disko, comin, sextant, ... }: {
    nixosConfigurations.installer-iso = nixpkgs.lib.nixosSystem {
      # Use aarch64-linux for Apple Silicon Macs, x86_64-linux for Intel
      system = "aarch64-linux";
      
      modules = [
        "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
        disko.nixosModules.disko
        # 3. Import the comin NixOS module so the system recognizes 'services.comin'
        comin.nixosModules.comin        
        # 3. Import the Sextant agent module
        sextant.nixosModules.agent        
        ({ pkgs, ... }: {
          # 1. Automated Disk Layout
          disko.devices.disk.main = {
            device = "/dev/vda";
            type = "disk";
            content = {
              type = "gpt";
              partitions = {
                ESP = {
                  type = "EF00";
                  size = "500M";
                  content = { type = "filesystem"; format = "vfat"; mountpoint = "/boot"; };
                };
                root = {
                  size = "100%";
                  content = { type = "filesystem"; format = "ext4"; mountpoint = "/"; };
                };
              };
            };
          };

          # 2. Embed Sextant Agent and comin
          services.comin = {
            enable = true;
            remotes = [{
              name = "origin";
              url = "https://github.com/rguikers/techlab-fleet.git";
              branches.main.name = "main";
            }];
          };

          services.sextant-agent = {
            enable = true;
            url = "https://fleet.assumed.world";
            tag = "test-vm";
          };

          # Inject the shared token for initial check-in
          environment.etc."sextant-token".text = "techlab-secure-enrollment-token";
          systemd.services.sextant-agent.serviceConfig.Environment = [
            "SEXTANT_CHECKIN_TOKEN_FILE=/etc/sextant-token"
          ];
          
          # 3. The Automation Script (Runs on boot)
          systemd.services.zero-touch-install = {
            description = "Zero-Touch Techlab fleet Installation";
            wantedBy = [ "multi-user.target" ];
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ];
            script = ''
              # Partition and format the disk automatically
              disko-mount
              
              # Install the system
              nixos-install --no-root-passwd --system /run/current-system
              
              # Reboot into the final OS
              reboot
            '';
          };
        })
      ];
    };
  };
}
