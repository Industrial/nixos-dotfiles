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
      enable = true;
    };
  };
}
