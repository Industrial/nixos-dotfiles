# LM Studio - Desktop application for experimenting with local and open-source Large Language Models (LLMs)
{pkgs, ...}: {
  environment = {
    systemPackages = with pkgs; [
      lmstudio
    ];
  };
}
