{pkgs, ...}: {
  claude-task-master = import ./claude-task-master/claude-task-master.test.nix {inherit pkgs;};
}
