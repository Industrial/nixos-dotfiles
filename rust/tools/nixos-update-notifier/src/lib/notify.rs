use notify_rust::Notification;
use thiserror::Error;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NotificationPayload {
    pub summary: String,
    pub body: String,
}

#[derive(Debug, Error)]
pub enum NotifyError {
    #[error("failed to send notification: {0}")]
    Send(String),
}

pub trait Notifier {
    fn notify(&mut self, payload: &NotificationPayload) -> Result<(), NotifyError>;
}

/// Desktop notifications via org.freedesktop.Notifications (GNOME banner + tray).
pub struct SystemNotifier;

impl Notifier for SystemNotifier {
    fn notify(&mut self, payload: &NotificationPayload) -> Result<(), NotifyError> {
        Notification::new()
            .summary(&payload.summary)
            .body(&payload.body)
            .appname("nixos-update-notifier")
            .timeout(0) // stay in notification center until dismissed
            .show()
            .map_err(|e| NotifyError::Send(e.to_string()))?;
        Ok(())
    }
}

/// Collect payloads for a package update set (one or more notifications).
pub fn payloads_for_updates(total_packages: usize, bodies: &[String]) -> Vec<NotificationPayload> {
    let parts = bodies.len().max(1);
    bodies
        .iter()
        .enumerate()
        .map(|(i, body)| {
            let summary = if parts == 1 {
                format!("NixOS updates available ({total_packages} packages)")
            } else {
                format!(
                    "NixOS updates available ({total_packages} packages, {}/{parts})",
                    i + 1
                )
            };
            NotificationPayload {
                summary,
                body: body.clone(),
            }
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn single_body_summary_includes_count() {
        let payloads = payloads_for_updates(2, &["firefox: 1 → 2\nlinux: 6 → 7".into()]);
        assert_eq!(payloads.len(), 1);
        assert_eq!(payloads[0].summary, "NixOS updates available (2 packages)");
        assert!(payloads[0].body.contains("firefox: 1 → 2"));
        assert!(payloads[0].body.contains("linux: 6 → 7"));
    }

    #[test]
    fn multi_body_summaries_are_numbered_and_list_all_packages() {
        let payloads = payloads_for_updates(3, &["a".into(), "b".into(), "c".into()]);
        assert_eq!(payloads.len(), 3);
        assert_eq!(
            payloads[0].summary,
            "NixOS updates available (3 packages, 1/3)"
        );
        assert_eq!(
            payloads[2].summary,
            "NixOS updates available (3 packages, 3/3)"
        );
        assert_eq!(payloads[0].body, "a");
        assert_eq!(payloads[1].body, "b");
        assert_eq!(payloads[2].body, "c");
    }
}
