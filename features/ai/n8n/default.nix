# No Code AI Framework.
{pkgs, ...}: {
  environment = {
    systemPackages = with pkgs; [
      n8n
      nodejs_latest
      supabase-cli
    ];
  };
  services = {
    n8n = {
      # https://localhost:5678
      enable = true;
    };
  };
}
