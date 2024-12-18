{
  inputs,
  settings,
  pkgs,
}: name: {
  enable = true;
  source =
    (import ../services/${name} {
      inherit settings pkgs;
      kubenix = inputs.kubenix;
      system = settings.system;
    })
    .config
    .kubernetes
    .result;
}
