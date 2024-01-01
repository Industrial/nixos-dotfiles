{settings, ...}: {
  programs.taskwarrior = {
    enable = true;
    config = {
      confirmation = false;
      report.minimal.filter = "status:pending";
      report.active.columns = ["id" "start" "entry.age" "priority" "project" "due" "description"];
      report.active.labels = ["ID" "Started" "Age" "Priority" "Project" "Due" "Description"];
      taskd = {
        certificate = "${settings.userdir}/.taskwarrior_certs/default-client.cert.pem";
        key = "${settings.userdir}/.taskwarrior_certs/default-client.key.pem";
        ca = "${settings.userdir}/.taskwarrior_certs/ca.cert.pem";
        server = "server.local:53589";
        credentials = "Default/Default/06eee0ff-b5f3-490f-9f3c-06015f4c8261";
        trust = "ignore hostname";
      };
    };
  };
}
