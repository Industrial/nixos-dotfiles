# A task management system for AI-driven development with Claude, designed to
# work seamlessly with Cursor AI.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    nodePackages_latest.claude-task-master
  ];
}
