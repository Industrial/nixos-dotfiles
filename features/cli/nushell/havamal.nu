# Hávamál — random stanza (parity with Fish conf.d/Hávamál.fish).
# Stanzas are linked at ~/.config/nushell/havamal-stanzas by Nix activation.

def havamal [] {
  let dir = ($nu.default-config-dir | path join "havamal-stanzas")
  if not ($dir | path exists) {
    error make {msg: $"Hávamál stanzas missing at ($dir). Rebuild NixOS to link them."}
  }
  let files = (ls $dir | where type == file | get name)
  if ($files | is-empty) {
    error make {msg: $"No Hávamál stanza files in ($dir)"}
  }
  open --raw ($files | shuffle | first)
}
