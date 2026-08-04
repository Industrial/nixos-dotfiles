//! Read-only SQLite access to Nix `db.sqlite`.

use std::collections::{HashMap, HashSet, VecDeque};
use std::path::{Path, PathBuf};

use rusqlite::{Connection, OpenFlags, OptionalExtension};

use crate::error::InfraError;
use crate::model::{PathInfo, QueryOpts, db_hash_to_sri};

pub const DEFAULT_STORE_ROOT: &str = "/nix";

/// Resolve `{store}/var/nix/db/db.sqlite`.
pub fn db_path_for_store(store_root: &Path) -> PathBuf {
    store_root.join("var/nix/db/db.sqlite")
}

/// Open Nix DB read-only via URI `mode=ro`.
pub fn open_db(db_path: &Path) -> Result<Connection, InfraError> {
    if !db_path.is_file() {
        return Err(InfraError::DbMissing(db_path.display().to_string()));
    }
    let uri = format!("file:{}?mode=ro", db_path.display());
    Connection::open_with_flags(
        &uri,
        OpenFlags::SQLITE_OPEN_READ_ONLY | OpenFlags::SQLITE_OPEN_URI,
    )
    .map_err(|e| InfraError::Sqlite(e.to_string()))
}

pub fn open_store_db(store_root: &Path) -> Result<Connection, InfraError> {
    open_db(&db_path_for_store(store_root))
}

struct RowMeta {
    id: i64,
    path: String,
    hash: String,
    registration_time: i64,
    deriver: Option<String>,
    nar_size: Option<i64>,
    ultimate: Option<i64>,
    sigs: Option<String>,
    ca: Option<String>,
}

fn load_row(conn: &Connection, path: &str) -> Result<RowMeta, InfraError> {
    conn.query_row(
        "SELECT id, path, hash, registrationTime, deriver, narSize, ultimate, sigs, ca \
         FROM ValidPaths WHERE path = ?1",
        [path],
        |r| {
            Ok(RowMeta {
                id: r.get(0)?,
                path: r.get(1)?,
                hash: r.get(2)?,
                registration_time: r.get(3)?,
                deriver: r.get(4)?,
                nar_size: r.get(5)?,
                ultimate: r.get(6)?,
                sigs: r.get(7)?,
                ca: r.get(8)?,
            })
        },
    )
    .optional()
    .map_err(|e| InfraError::Sqlite(e.to_string()))?
    .ok_or_else(|| InfraError::UnknownPath(path.into()))
}

fn refs_for(conn: &Connection, id: i64) -> Result<Vec<String>, InfraError> {
    let mut stmt = conn
        .prepare(
            "SELECT v.path FROM Refs r JOIN ValidPaths v ON v.id = r.reference \
             WHERE r.referrer = ?1 ORDER BY v.path",
        )
        .map_err(|e| InfraError::Sqlite(e.to_string()))?;
    let rows = stmt
        .query_map([id], |r| r.get::<_, String>(0))
        .map_err(|e| InfraError::Sqlite(e.to_string()))?;
    let mut out = Vec::new();
    for row in rows {
        out.push(row.map_err(|e| InfraError::Sqlite(e.to_string()))?);
    }
    Ok(out)
}

fn referrers_for(conn: &Connection, id: i64) -> Result<Vec<String>, InfraError> {
    let mut stmt = conn
        .prepare(
            "SELECT v.path FROM Refs r JOIN ValidPaths v ON v.id = r.referrer \
             WHERE r.reference = ?1 ORDER BY v.path",
        )
        .map_err(|e| InfraError::Sqlite(e.to_string()))?;
    let rows = stmt
        .query_map([id], |r| r.get::<_, String>(0))
        .map_err(|e| InfraError::Sqlite(e.to_string()))?;
    let mut out = Vec::new();
    for row in rows {
        out.push(row.map_err(|e| InfraError::Sqlite(e.to_string()))?);
    }
    Ok(out)
}

fn path_id(conn: &Connection, path: &str) -> Result<Option<(i64, u64)>, InfraError> {
    conn.query_row(
        "SELECT id, COALESCE(narSize, 0) FROM ValidPaths WHERE path = ?1",
        [path],
        |r| Ok((r.get::<_, i64>(0)?, r.get::<_, i64>(1)? as u64)),
    )
    .optional()
    .map_err(|e| InfraError::Sqlite(e.to_string()))
}

fn closure_size(conn: &Connection, root_path: &str) -> Result<u64, InfraError> {
    let Some((root_id, root_size)) = path_id(conn, root_path)? else {
        return Err(InfraError::UnknownPath(root_path.into()));
    };
    let mut seen: HashSet<i64> = HashSet::new();
    let mut q: VecDeque<i64> = VecDeque::new();
    let mut sizes: HashMap<i64, u64> = HashMap::new();
    seen.insert(root_id);
    q.push_back(root_id);
    sizes.insert(root_id, root_size);

    let mut stmt = conn
        .prepare(
            "SELECT r.reference, COALESCE(v.narSize, 0) FROM Refs r \
             JOIN ValidPaths v ON v.id = r.reference WHERE r.referrer = ?1",
        )
        .map_err(|e| InfraError::Sqlite(e.to_string()))?;

    while let Some(id) = q.pop_front() {
        let rows = stmt
            .query_map([id], |r| Ok((r.get::<_, i64>(0)?, r.get::<_, i64>(1)? as u64)))
            .map_err(|e| InfraError::Sqlite(e.to_string()))?;
        for row in rows {
            let (ref_id, sz) = row.map_err(|e| InfraError::Sqlite(e.to_string()))?;
            if seen.insert(ref_id) {
                sizes.insert(ref_id, sz);
                q.push_back(ref_id);
            }
        }
    }
    Ok(sizes.values().sum())
}

/// Query path-info for one store path.
pub fn query_path_info(
    conn: &Connection,
    path: &str,
    opts: QueryOpts,
) -> Result<PathInfo, InfraError> {
    let row = load_row(conn, path)?;
    let nar_hash = db_hash_to_sri(&row.hash)?;
    let nar_size = row.nar_size.unwrap_or(0).max(0) as u64;
    let references = refs_for(conn, row.id)?;
    let referrers = if opts.include_referrers {
        Some(referrers_for(conn, row.id)?)
    } else {
        None
    };
    let closure = if opts.include_closure_size {
        Some(closure_size(conn, path)?)
    } else {
        None
    };
    let signatures = row
        .sigs
        .as_deref()
        .map(|s| {
            s.split_whitespace()
                .filter(|x| !x.is_empty())
                .map(str::to_string)
                .collect()
        })
        .unwrap_or_default();

    Ok(PathInfo {
        path: row.path,
        nar_hash,
        nar_size,
        deriver: row.deriver,
        registration_time: row.registration_time,
        ultimate: row.ultimate.unwrap_or(0) != 0,
        signatures,
        ca: row.ca,
        references,
        referrers,
        closure_size: closure,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fixture_root() -> PathBuf {
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("fixtures/minimal")
    }

    #[test]
    fn opens_fixture_and_queries() {
        let conn = open_store_db(&fixture_root()).expect("open");
        let path = "/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-a";
        let info = query_path_info(&conn, path, QueryOpts::default()).expect("query");
        assert_eq!(info.path, path);
        assert_eq!(info.nar_size, 100);
        assert!(info.nar_hash.starts_with("sha256-"));
        assert_eq!(info.references.len(), 2);
    }

    #[test]
    fn unknown_path_errors() {
        let conn = open_store_db(&fixture_root()).expect("open");
        let err = query_path_info(&conn, "/nix/store/missing", QueryOpts::default()).unwrap_err();
        assert!(matches!(err, InfraError::UnknownPath(_)));
    }

    #[test]
    fn referrers_and_closure() {
        let conn = open_store_db(&fixture_root()).expect("open");
        let path = "/nix/store/cccccccccccccccccccccccccccccccc-c";
        let info = query_path_info(
            &conn,
            path,
            QueryOpts {
                include_referrers: true,
                include_closure_size: true,
            },
        )
        .expect("query");
        assert!(info.referrers.as_ref().unwrap().len() >= 2);
        assert_eq!(info.closure_size, Some(50)); // c only refs self
    }


    #[test]
    fn golden_json_matches() {
        let conn = open_store_db(&fixture_root()).expect("open");
        let path = "/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-a";
        let info = query_path_info(
            &conn,
            path,
            QueryOpts {
                include_referrers: true,
                include_closure_size: true,
            },
        )
        .expect("query");
        let v = info.to_json_value();
        let golden: serde_json::Value = serde_json::from_str(
            &std::fs::read_to_string(
                PathBuf::from(env!("CARGO_MANIFEST_DIR"))
                    .join("fixtures/minimal/golden-path-info-a.json"),
            )
            .unwrap(),
        )
        .unwrap();
        assert_eq!(v, golden);
    }

    #[test]
    fn golden_referrers_c() {
        let conn = open_store_db(&fixture_root()).expect("open");
        let path = "/nix/store/cccccccccccccccccccccccccccccccc-c";
        let info = query_path_info(
            &conn,
            path,
            QueryOpts {
                include_referrers: true,
                include_closure_size: true,
            },
        )
        .expect("query");
        let v = info.to_json_value();
        let golden: serde_json::Value = serde_json::from_str(
            &std::fs::read_to_string(
                PathBuf::from(env!("CARGO_MANIFEST_DIR"))
                    .join("fixtures/minimal/golden-referrers-c.json"),
            )
            .unwrap(),
        )
        .unwrap();
        assert_eq!(v, golden);
    }

    #[test]
    fn missing_db() {
        let err = open_db(Path::new("/tmp/nixstore-no-such-db.sqlite")).unwrap_err();
        assert!(matches!(err, InfraError::DbMissing(_)));
    }
}
