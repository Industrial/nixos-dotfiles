// Export the live board back to the declarative JSON shape of board.json.
// Secret values are never exported (they live in api-keys.nix); only the
// secret key names are kept, so a UI-created integration survives round-trips.
const Database = require("/app/node_modules/better-sqlite3");

const db = new Database("/appdata/db/db.sqlite", { readonly: true });
const board = db.prepare("SELECT id,name FROM board ORDER BY rowid LIMIT 1").get();
const layout = db.prepare("SELECT id FROM layout WHERE board_id = ? AND name = 'Base'").get(board.id)
  || db.prepare("SELECT id FROM layout WHERE board_id = ?").get(board.id);

const spec = {board: {name: board.name}, integrations: [], apps: []};

for (const i of db.prepare("SELECT id,name,url,kind FROM integration").all()) {
  const secrets = {};
  for (const s of db.prepare("SELECT kind FROM integrationSecret WHERE integration_id = ?").all(i.id)) {
    secrets[s.kind] = "SET-IN-api-keys-nix";
  }
  spec.integrations.push({name: i.name, kind: i.kind, url: i.url, secrets});
}

const appItems = db.prepare(
  `SELECT i.kind, i.options, il.x_offset x, il.y_offset y
   FROM item i LEFT JOIN item_layout il
     ON il.item_id = i.id AND il.layout_id = ?
   WHERE i.board_id = ?`
).all(layout.id, board.id);

for (const it of appItems) {
  let opts = {};
  try { opts = JSON.parse(it.options).json || {}; } catch {}
  if (it.kind === "app") {
    const arow = db.prepare("SELECT name,href,ping_url FROM app WHERE id = ?").get(opts.appId);
    if (arow) {
      spec.apps.push({
        name: arow.name,
        url: arow.href,
        pingUrl: arow.ping_url ?? undefined,
        x: it.x ?? 0,
        y: it.y ?? 0,
      });
    }
  } else {
    spec.apps.push({kind: it.kind, options: opts, x: it.x ?? 0, y: it.y ?? 0});
  }
}

console.log(JSON.stringify(spec, null, 2));
