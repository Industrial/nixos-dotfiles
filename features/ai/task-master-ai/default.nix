{pkgs, ...}: {
  environment = {
    systemPackages = with pkgs; [
      task-master-ai
    ];
  };
}
