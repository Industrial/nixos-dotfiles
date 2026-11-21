# Trim a captured `--log-format internal-json -v` log to a fixture (tests/fixtures):
# the daemon's `linking` chatter, the talkative `evaluating file` lines and the
# eval's untyped activities cut to a sample, progress results deduplicated (only a
# change is kept), wrapper lines dropped. The checkout path is then replaced:
#   awk -f tests/trim.awk capture.jsonl | sed "s|$PWD|/build/dotfiles|g" > tests/fixtures/x.jsonl
/^vmtest: / { next }
!/^@nix / { print; next }
/"action":"msg","level":0,"msg":"linking/ { if (++linking <= 20) print; next }
/"action":"msg","level":4,/ { if (++talk <= 20) print; next }
/"action":"start"/ && /"type":0}$/ {
  match($0, /"id":[0-9]+/); id = substr($0, RSTART, RLENGTH)
  if (++untyped <= 50) print; else dropped[id] = 1
  next
}
/"action":"stop"/ {
  match($0, /"id":[0-9]+/); id = substr($0, RSTART, RLENGTH)
  if (id in dropped) next
  print; next
}
/"action":"result"/ && (/"type":105}$/ || /"type":106}$/) {
  match($0, /"id":[0-9]+/); id = substr($0, RSTART, RLENGTH)
  t = substr($0, length($0) - 3, 3)
  match($0, /"fields":\[[^]]*\]/); f = substr($0, RSTART, RLENGTH)
  k = id t
  if (t == "106") { match(f, /\[[0-9]+/); k = k substr(f, RSTART, RLENGTH) }
  if (last[k] == f) next
  last[k] = f; print; next
}
{ print }
