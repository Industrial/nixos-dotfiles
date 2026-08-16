use crate::diff::PackageChange;

/// Format one package change as a notification line.
pub fn format_package_line(change: &PackageChange) -> String {
    change.to_string()
}

/// Split package lines into bodies that each fit within `body_limit` characters.
///
/// Never drops packages: if a single line exceeds the limit it becomes its own body.
pub fn chunk_package_lines(lines: &[String], body_limit: usize) -> Vec<String> {
    if lines.is_empty() {
        return Vec::new();
    }

    let limit = body_limit.max(1);
    let mut bodies = Vec::new();
    let mut current = String::new();

    for line in lines {
        if current.is_empty() {
            if line.len() <= limit {
                current = line.clone();
            } else {
                bodies.push(line.clone());
            }
            continue;
        }

        let extra = 1 + line.len(); // newline + line
        if current.len() + extra <= limit {
            current.push('\n');
            current.push_str(line);
        } else {
            bodies.push(std::mem::take(&mut current));
            if line.len() <= limit {
                current = line.clone();
            } else {
                bodies.push(line.clone());
            }
        }
    }

    if !current.is_empty() {
        bodies.push(current);
    }
    bodies
}

/// Build notification bodies listing every package change.
pub fn format_notification_bodies(changes: &[PackageChange], body_limit: usize) -> Vec<String> {
    let lines: Vec<String> = changes.iter().map(format_package_line).collect();
    chunk_package_lines(&lines, body_limit)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ch(name: &str, detail: &str) -> PackageChange {
        PackageChange::new(name, detail)
    }

    #[test]
    fn chunk_empty_returns_empty() {
        assert!(chunk_package_lines(&[], 100).is_empty());
    }

    #[test]
    fn chunk_keeps_all_lines_under_limit() {
        let lines = vec!["a: 1 → 2".into(), "b: 3 → 4".into()];
        let bodies = chunk_package_lines(&lines, 100);
        assert_eq!(bodies, vec!["a: 1 → 2\nb: 3 → 4"]);
    }

    #[test]
    fn chunk_splits_without_dropping_packages() {
        let lines = vec![
            "firefox: 1 → 2".into(),
            "linux: 6 → 7".into(),
            "zsh: 5 → 6".into(),
        ];
        let bodies = chunk_package_lines(&lines, 14);
        assert_eq!(bodies.len(), 3);
        assert_eq!(bodies[0], "firefox: 1 → 2");
        assert_eq!(bodies[1], "linux: 6 → 7");
        assert_eq!(bodies[2], "zsh: 5 → 6");
    }

    #[test]
    fn chunk_keeps_oversized_line_as_own_body() {
        let long = "x".repeat(50);
        let bodies = chunk_package_lines(&[long.clone()], 10);
        assert_eq!(bodies, vec![long]);
    }

    #[test]
    fn notification_bodies_list_exact_package_names() {
        let changes = vec![
            ch("firefox", "128.0 → 129.0"),
            ch("linux", "6.12.1 → 6.12.5"),
        ];
        let bodies = format_notification_bodies(&changes, 900);
        assert_eq!(bodies.len(), 1);
        assert!(bodies[0].contains("firefox: 128.0 → 129.0"));
        assert!(bodies[0].contains("linux: 6.12.1 → 6.12.5"));
    }
}
