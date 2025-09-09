{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    zotero
    # zotero-connector
    # zotero-better-bibtex
    # zotero-zotfile
    # zotero-scholar-citations
  ];
}
