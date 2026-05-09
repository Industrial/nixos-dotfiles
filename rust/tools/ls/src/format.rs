//! Long listing formatting (GNU-oriented).

use std::fs::Metadata;
use std::path::Path;

#[cfg(unix)]
use std::os::unix::fs::{FileTypeExt, MetadataExt};

/// First column of `ls -l`: type + nine permission characters (GNU-style specials).
#[cfg(unix)]
pub fn mode_string(meta: &Metadata) -> String {
    let mode = meta.mode();
    let perm = mode & 0o7777;
    let ft = meta.file_type();
    let mut s = String::with_capacity(10);
    s.push(file_type_char(meta, &ft));
    let owner = (perm >> 6) & 7;
    let group = (perm >> 3) & 7;
    let other = perm & 7;
    let setuid = mode & 0o4000 != 0;
    let setgid = mode & 0o2000 != 0;
    let sticky = mode & 0o1000 != 0;
    s.push_str(&triplet(owner, setuid));
    s.push_str(&triplet(group, setgid));
    s.push_str(&triplet_other(other, sticky));
    s
}

#[cfg(unix)]
fn triplet(bits: u32, set_id: bool) -> String {
    let r = bits & 4 != 0;
    let w = bits & 2 != 0;
    let x = bits & 1 != 0;
    let exec_ch = if set_id {
        if x { 's' } else { 'S' }
    } else if x {
        'x'
    } else {
        '-'
    };
    format!(
        "{}{}{}",
        if r { 'r' } else { '-' },
        if w { 'w' } else { '-' },
        exec_ch
    )
}

#[cfg(unix)]
fn triplet_other(bits: u32, sticky: bool) -> String {
    let r = bits & 4 != 0;
    let w = bits & 2 != 0;
    let x = bits & 1 != 0;
    let exec_ch = if sticky {
        if x { 't' } else { 'T' }
    } else if x {
        'x'
    } else {
        '-'
    };
    format!(
        "{}{}{}",
        if r { 'r' } else { '-' },
        if w { 'w' } else { '-' },
        exec_ch
    )
}

#[cfg(unix)]
fn file_type_char(_meta: &Metadata, ft: &std::fs::FileType) -> char {
    if ft.is_fifo() {
        'p'
    } else if ft.is_char_device() {
        'c'
    } else if ft.is_block_device() {
        'b'
    } else if ft.is_dir() {
        'd'
    } else if ft.is_symlink() {
        'l'
    } else if ft.is_socket() {
        's'
    } else {
        '-'
    }
}

#[cfg(not(unix))]
pub fn mode_string(_meta: &Metadata) -> String {
    "----------".to_string()
}

/// Human-readable size column: device major,minor or byte length (symlink: link text length).
/// Glibc `gnu_dev_major` / `gnu_dev_minor` for 64-bit `dev_t` (see `bits/sysmacros.h`).
#[cfg(all(unix, target_os = "linux"))]
fn gnu_dev_major_minor(dev: u64) -> (u32, u32) {
    const MA_LOW: u64 = 0xfff00;
    const MA_HIGH: u64 = 0xffff_f000_0000_0000;
    const MI_MID: u64 = 0xffffff00000;
    let major = ((dev & MA_LOW) >> 8) as u32 | ((dev & MA_HIGH) >> 32) as u32;
    let minor = ((dev & 0xff) as u32) | (((dev & MI_MID) >> 12) as u32);
    (major, minor)
}

#[cfg(all(unix, target_os = "linux"))]
pub fn size_or_device(meta: &Metadata) -> String {
    let ft = meta.file_type();
    if ft.is_block_device() || ft.is_char_device() {
        let (major, minor) = gnu_dev_major_minor(meta.rdev());
        format!("{major}, {minor}")
    } else {
        format!("{}", meta.len())
    }
}

#[cfg(all(unix, not(target_os = "linux")))]
pub fn size_or_device(meta: &Metadata) -> String {
    let ft = meta.file_type();
    if ft.is_block_device() || ft.is_char_device() {
        let dev = meta.rdev();
        format!("{dev}, 0")
    } else {
        format!("{}", meta.len())
    }
}

#[cfg(not(unix))]
pub fn size_or_device(meta: &Metadata) -> String {
    format!("{}", meta.len())
}

/// GNU-style mtime column (current locale / six-month rule) — `LC_TIME=C` tests use English abbreviations.
pub fn format_mtime(meta: &Metadata, now: chrono::DateTime<chrono::Local>) -> String {
    use chrono::Local;
    use chrono::TimeZone;

    let modified = match meta.modified().ok().and_then(|t| {
        t.duration_since(std::time::UNIX_EPOCH)
            .ok()
            .map(|d| d.as_secs() as i64)
    }) {
        Some(secs) => Local.timestamp_opt(secs, 0).single(),
        None => None,
    };

    let Some(ts) = modified else {
        return "?".to_string();
    };

    let half_year = chrono::Duration::days(183);
    let show_year = ts > now + half_year || now - ts > half_year;
    if show_year {
        ts.format("%b %e  %Y").to_string()
    } else {
        ts.format("%b %e %H:%M").to_string()
    }
}

/// Display name for `-l`: for symlinks, append ` -> target` (GNU).
pub fn long_name(path: &Path, meta: &Metadata) -> String {
    let name = path
        .file_name()
        .map(|s| s.to_string_lossy().into_owned())
        .unwrap_or_else(|| path.to_string_lossy().into_owned());
    if meta.file_type().is_symlink() {
        if let Ok(target) = std::fs::read_link(path) {
            return format!("{} -> {}", name, target.display());
        }
    }
    name
}

#[cfg(unix)]
pub fn nlink(meta: &Metadata) -> u64 {
    meta.nlink()
}

#[cfg(not(unix))]
pub fn nlink(_meta: &Metadata) -> u64 {
    1
}

#[cfg(unix)]
pub fn blocks_512(meta: &Metadata) -> u64 {
    meta.blocks()
}

#[cfg(not(unix))]
pub fn blocks_512(_meta: &Metadata) -> u64 {
    0
}

#[cfg(unix)]
pub fn uid_gid_names(meta: &Metadata) -> (String, String) {
    let uid = meta.uid();
    let gid = meta.gid();
    let user = uzers::get_user_by_uid(uid)
        .map(|u| u.name().to_string_lossy().into_owned())
        .unwrap_or_else(|| uid.to_string());
    let group = uzers::get_group_by_gid(gid)
        .map(|g| g.name().to_string_lossy().into_owned())
        .unwrap_or_else(|| gid.to_string());
    (user, group)
}

#[cfg(not(unix))]
pub fn uid_gid_names(_meta: &Metadata) -> (String, String) {
    ("0".to_string(), "0".to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[cfg(unix)]
    #[cfg(all(target_os = "linux", test))]
    mod gnu_dev_major_minor {
        use super::super::gnu_dev_major_minor;

        #[test]
        fn decodes_classic_dev_encoding() {
            let (maj, min) = gnu_dev_major_minor(0x103);
            assert_eq!((maj, min), (1, 3));
        }
    }

    mod mode_string {
        use super::*;
        use std::fs;
        use std::os::unix::fs::PermissionsExt;

        #[test]
        fn regular_file_default_mode_is_minus_rw_r_r() {
            let tmp = tempfile::tempdir().expect("tmp");
            let p = tmp.path().join("f");
            fs::write(&p, b"x").unwrap();
            let meta = fs::symlink_metadata(&p).unwrap();
            let m = mode_string(&meta);
            assert_eq!(m.len(), 10);
            assert!(m.starts_with('-'));
        }

        #[test]
        fn setuid_shows_s_in_owner_execute_when_executable() {
            let tmp = tempfile::tempdir().expect("tmp");
            let p = tmp.path().join("setuid_exec");
            fs::write(&p, b"").unwrap();
            let mut perms = fs::metadata(&p).unwrap().permissions();
            perms.set_mode(0o4755);
            fs::set_permissions(&p, perms).unwrap();
            let meta = fs::symlink_metadata(&p).unwrap();
            let m = mode_string(&meta);
            assert_eq!(&m[1..4], "rws");
        }

        #[test]
        fn setuid_shows_cap_s_when_not_executable() {
            let tmp = tempfile::tempdir().expect("tmp");
            let p = tmp.path().join("setuid_noexec");
            fs::write(&p, b"").unwrap();
            let mut perms = fs::metadata(&p).unwrap().permissions();
            perms.set_mode(0o4644);
            fs::set_permissions(&p, perms).unwrap();
            let meta = fs::symlink_metadata(&p).unwrap();
            let m = mode_string(&meta);
            assert_eq!(&m[1..4], "rwS");
        }

        #[test]
        fn sticky_dir_shows_t_when_other_executable() {
            let tmp = tempfile::tempdir().expect("tmp");
            let p = tmp.path().join("sticky");
            fs::create_dir(&p).unwrap();
            let mut perms = fs::metadata(&p).unwrap().permissions();
            perms.set_mode(0o1777);
            fs::set_permissions(&p, perms).unwrap();
            let meta = fs::symlink_metadata(&p).unwrap();
            let m = mode_string(&meta);
            assert_eq!(&m[7..10], "rwt");
        }
    }
}
