// Reconcile homarr's sqlite DB with the declarative board spec.
// Idempotent: creates/updates apps, items, positions; never deletes
// items it didn't declare (manual additions survive).
// Usage: node reconcile.js <spec.json>
const crypto = require("crypto");
const fs = require("fs");
const Database = require("/app/node_modules/better-sqlite3");

const keyHex = process.env.SECRET_ENCRYPTION_KEY;
if (!keyHex || keyHex.length !== 64) {
  console.error("SECRET_ENCRYPTION_KEY must be 64 hex chars");
  process.exit(1);
}
const spec = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));

function id() {
  // homarr uses nanoid-style 24-char lowercase alphanumeric ids
  const alphabet = "abcdefghijklmnopqrstuvwxyz0123456789";
  let s = "";
  for (const b of crypto.randomBytes(24)) s += alphabet[b % alphabet.length];
  return s;
}
function encryptSecret(value) {
  if (!value) return null;
  const iv = crypto.randomBytes(16);
  const c = crypto.createCipheriv("aes-256-cbc", Buffer.from(keyHex, "hex"), iv);
  const enc = Buffer.concat([c.update(String(value)), c.final()]);
  return `${enc.toString("hex")}.${iv.toString("hex")}`;
}

const db = new Database("/appdata/db/db.sqlite");
db.pragma("journal_mode = WAL");

// --- board -------------------------------------------------------------
let board = db.prepare("SELECT id FROM board WHERE name = ?").get(spec.board.name);
if (!board) {
  const bid = id();
  db.prepare("INSERT INTO board (id,name,is_public) VALUES (?, ?, 0)").run(bid, spec.board.name);
  board = {id: bid};
}
const boardId = board.id;

// --- layout + section --------------------------------------------------
let layout = db.prepare("SELECT id FROM layout WHERE board_id = ? AND name = ?").get(boardId, "Base");
if (!layout) {
  const lid = id();
  db.prepare("INSERT INTO layout (id,name,board_id,column_count,breakpoint) VALUES (?, 'Base', ?, 12, 0)").run(lid, boardId);
  layout = {id: lid};
}
let section = db.prepare("SELECT id FROM section WHERE board_id = ?").get(boardId);
if (!section) {
  const sid = id();
  db.prepare("INSERT INTO section (id,board_id,kind,x_offset,y_offset,options) VALUES (?, ?, 'empty', 0, 0, ?)")
    .run(sid, boardId, JSON.stringify({json: {}}));
  section = {id: sid};
}

// --- integrations (service connections with secrets) -------------------
for (const integ of spec.integrations || []) {
  let row = db.prepare("SELECT id FROM integration WHERE name = ?").get(integ.name);
  if (!row) {
    const iid = id();
    db.prepare("INSERT INTO integration (id,name,url,kind,app_id) VALUES (?, ?, ?, ?, NULL)")
      .run(iid, integ.name, integ.url, integ.kind);
    row = {id: iid};
    console.log(`integration created: ${integ.name} (${integ.kind})`);
  } else {
    db.prepare("UPDATE integration SET url = ?, kind = ? WHERE id = ?").run(integ.url, integ.kind, row.id);
  }
  for (const [kind, value] of Object.entries(integ.secrets || {})) {
    const enc = encryptSecret(value);
    const existing = db.prepare("SELECT kind FROM integrationSecret WHERE integration_id = ? AND kind = ?").get(row.id, kind);
    if (existing) {
      db.prepare("UPDATE integrationSecret SET value = ?, updated_at = strftime('%s','now') WHERE integration_id = ? AND kind = ?")
        .run(enc, row.id, kind);
    } else {
      db.prepare("INSERT INTO integrationSecret (kind,value,updated_at,integration_id) VALUES (?, ?, strftime('%s','now'), ?)")
        .run(kind, enc, row.id);
    }
    console.log(`secret set: ${integ.name}.${kind}`);
  }
}

// --- app tiles ----------------------------------------------------------
for (const app of spec.apps || []) {
  let arow = db.prepare("SELECT id FROM app WHERE name = ?").get(app.name);
  if (!arow) {
    const aid = id();
    db.prepare("INSERT INTO app (id,name,url,href,ping_url) VALUES (?, ?, ?, ?, ?)")
      .run(aid, app.name, app.url ?? null, app.href ?? app.url ?? null, app.pingUrl ?? null);
    arow = {id: aid};
    console.log(`app created: ${app.name}`);
  } else {
    db.prepare("UPDATE app SET url = ?, href = ?, ping_url = ? WHERE id = ?")
      .run(app.url ?? null, app.href ?? app.url ?? null, app.pingUrl ?? null, arow.id);
  }

  // tile on the board bound to the app
  let item = db.prepare("SELECT i.id FROM item i JOIN item_layout il ON il.item_id = i.id WHERE i.board_id = ? AND i.kind = 'app' AND i.options LIKE ?")
    .get(boardId, `%"appId":"${arow.id}"%`);
  if (!item) {
    const iid = id();
    db.prepare("INSERT INTO item (id,board_id,kind,options,advanced_options) VALUES (?, ?, 'app', ?, ?)")
      .run(iid, boardId,
        JSON.stringify({json: {appId: arow.id, openInNewTab: true, showTitle: true}}),
        JSON.stringify({json: {}}));
    db.prepare("INSERT INTO item_layout (item_id,section_id,layout_id,x_offset,y_offset,width,height) VALUES (?, ?, ?, ?, ?, 1, 1)")
      .run(iid, section.id, layout.id, app.x ?? 0, app.y ?? 0);
    item = {id: iid};
    console.log(`tile added: ${app.name}`);
  } else {
    db.prepare("UPDATE item_layout SET x_offset = ?, y_offset = ? WHERE item_id = ?")
      .run(app.x ?? 0, app.y ?? 0, item.id);
  }
}

// --- make it the home board -------------------------------------------
db.prepare("UPDATE serverSetting SET value = ? WHERE setting_key = 'board'").run(
  JSON.stringify({json: {homeBoardId: boardId, mobileHomeBoardId: null, enableStatusByDefault: true, forceDisableStatus: false}})
);

console.log("reconcile complete");
