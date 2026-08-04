//! Streaming reporter for assay outcomes.
//!
//! ## Backpressure (v1)
//!
//! Outcomes are **buffered entirely** before any formatted output is emitted:
//! `Stream::from_iterable` materializes the input slice, then combinators map/format
//! the batch. Live per-case printing during suite execution is deferred to a later
//! wave when the runner yields a true incremental `Stream` of case results.

use std::fmt::Write as _;
use std::io::{self, Write};

use id_effect::{Effect, Stream, runtime::run_blocking};
use serde::Serialize;

use crate::outcome::AssayOutcome;
use crate::run::RunSummary;

/// Output format for assay run reports.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum ReportFormat {
    #[default]
    Human,
    Json,
    Tap,
}

impl ReportFormat {
    /// Parse a CLI `--format` value (`human`, `json`, `tap`).
    pub fn parse(s: &str) -> Option<Self> {
        match s.to_ascii_lowercase().as_str() {
            "human" => Some(Self::Human),
            "json" => Some(Self::Json),
            "tap" => Some(Self::Tap),
            _ => None,
        }
    }
}

/// One formatted output line (or block) produced by the stream reporter.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReportLine {
    pub body: String,
}

#[derive(Serialize)]
struct JsonOutcome {
    name: String,
    outcome: AssayOutcome,
}

/// Build a finite stream over case outcomes (buffer-all v1).
pub fn outcome_stream(
    outcomes: &[(String, AssayOutcome)],
) -> Stream<(String, AssayOutcome), (), ()> {
    let owned: Vec<(String, AssayOutcome)> = outcomes.to_vec();
    Stream::from_iterable(owned)
}

/// Map each outcome to a [`ReportLine`] for the chosen format.
pub fn format_line(
    index: usize,
    name: &str,
    outcome: &AssayOutcome,
    format: ReportFormat,
) -> ReportLine {
    let body = match format {
        ReportFormat::Human => format_human_line(name, outcome),
        ReportFormat::Tap => format_tap_line(index, name, outcome),
        ReportFormat::Json => unreachable!("json uses batch encoding, not per-line format"),
    };
    ReportLine { body }
}

fn outcome_mark(outcome: &AssayOutcome) -> &'static str {
    match outcome {
        AssayOutcome::Pass => "PASS",
        AssayOutcome::EvalError { .. }
        | AssayOutcome::Recursion
        | AssayOutcome::Timeout
        | AssayOutcome::ResourceLeak => "ERR",
        _ => "FAIL",
    }
}

fn format_human_line(name: &str, outcome: &AssayOutcome) -> String {
    let mut line = format!("{} {name}", outcome_mark(outcome));
    match outcome {
        AssayOutcome::Fail { diff, .. } => {
            let _ = write!(line, "\n  {diff}");
        }
        AssayOutcome::EvalError { message, .. } => {
            let _ = write!(line, "\n  {message}");
        }
        _ => {}
    }
    line
}

fn format_tap_line(index: usize, name: &str, outcome: &AssayOutcome) -> String {
    match outcome {
        AssayOutcome::Pass => format!("ok {index} - {name}"),
        _ => {
            let detail = match outcome {
                AssayOutcome::Fail { diff, .. } => diff.as_str(),
                AssayOutcome::EvalError { message, .. } => message.as_str(),
                AssayOutcome::SnapshotMismatch { diff, .. } => diff.as_str(),
                AssayOutcome::Counterexample { .. } => "counterexample",
                AssayOutcome::Recursion => "infinite recursion",
                AssayOutcome::Timeout => "timeout",
                AssayOutcome::ResourceLeak => "resource leak",
                AssayOutcome::Pass => "",
            };
            if detail.is_empty() {
                format!("not ok {index} - {name}")
            } else {
                format!("not ok {index} - {name}\n  {detail}")
            }
        }
    }
}

fn format_summary(summary: &RunSummary) -> String {
    format!(
        "\n{}/{} passed, {} failed, {} errored",
        summary.passed, summary.total, summary.failed, summary.errored
    )
}

fn write_json(outcomes: &[(String, AssayOutcome)], writer: &mut dyn Write) -> io::Result<()> {
    let rows: Vec<JsonOutcome> = outcomes
        .iter()
        .map(|(name, outcome)| JsonOutcome {
            name: name.clone(),
            outcome: outcome.clone(),
        })
        .collect();
    writeln!(
        writer,
        "{}",
        serde_json::to_string_pretty(&rows).map_err(io::Error::other)?
    )
}

/// Emit a full report for `outcomes` to `writer`.
///
/// v1 buffers all outcomes before writing (see module docs).
pub fn report_outcomes(
    outcomes: &[(String, AssayOutcome)],
    format: ReportFormat,
    summary: &RunSummary,
    writer: &mut dyn Write,
) -> io::Result<()> {
    match format {
        ReportFormat::Json => write_json(outcomes, writer),
        ReportFormat::Human | ReportFormat::Tap => {
            let indexed: Vec<(usize, String, AssayOutcome)> = outcomes
                .iter()
                .enumerate()
                .map(|(idx, (name, outcome))| (idx + 1, name.clone(), outcome.clone()))
                .collect();
            let lines: Vec<ReportLine> = run_blocking(
                Stream::from_iterable(indexed)
                    .map(move |(idx, name, outcome)| format_line(idx, &name, &outcome, format))
                    .run_collect(),
                (),
            )
            .map_err(|e| io::Error::other(format!("stream collect failed: {e:?}")))?;

            if format == ReportFormat::Tap {
                writeln!(writer, "TAP version 13")?;
                writeln!(writer, "1..{}", summary.total)?;
            }

            for line in lines {
                writeln!(writer, "{}", line.body)?;
            }

            if format == ReportFormat::Human {
                write!(writer, "{}", format_summary(summary))?;
            }
            Ok(())
        }
    }
}

/// Convenience: report to stdout.
pub fn report_outcomes_stdout(
    outcomes: &[(String, AssayOutcome)],
    format: ReportFormat,
    summary: &RunSummary,
) -> io::Result<()> {
    let mut stdout = io::stdout().lock();
    report_outcomes(outcomes, format, summary, &mut stdout)
}

/// Effectful sink: print each [`ReportLine`] as it is produced (still buffer-all upstream).
pub fn print_lines_effect(lines: Vec<ReportLine>) -> Effect<(), (), ()> {
    Effect::new(move |_env: &mut ()| {
        for line in lines {
            println!("{}", line.body);
        }
        Ok(())
    })
}

/// Map outcomes through a stream and collect formatted lines (test helper / future live path).
pub fn collect_formatted_lines(
    outcomes: &[(String, AssayOutcome)],
    format: ReportFormat,
) -> Vec<ReportLine> {
    if format == ReportFormat::Json {
        return Vec::new();
    }
    run_blocking(
        Stream::from_iterable(
            outcomes
                .iter()
                .enumerate()
                .map(|(idx, (name, outcome))| (idx + 1, name.clone(), outcome.clone()))
                .collect::<Vec<_>>(),
        )
        .map(move |(idx, name, outcome)| format_line(idx, &name, &outcome, format))
        .run_collect(),
        (),
    )
    .expect("collect_formatted_lines")
}

#[cfg(test)]
mod tests {
    use id_effect::succeed;

    use super::*;

    fn sample_outcomes() -> Vec<(String, AssayOutcome)> {
        vec![
            ("passing".into(), AssayOutcome::Pass),
            (
                "failing".into(),
                AssayOutcome::Fail {
                    claim: "eq".into(),
                    left: None,
                    right: None,
                    diff: "values differ".into(),
                },
            ),
        ]
    }

    #[test]
    fn report_format_parse() {
        assert_eq!(ReportFormat::parse("human"), Some(ReportFormat::Human));
        assert_eq!(ReportFormat::parse("JSON"), Some(ReportFormat::Json));
        assert_eq!(ReportFormat::parse("tap"), Some(ReportFormat::Tap));
        assert_eq!(ReportFormat::parse("yaml"), None);
    }

    #[test]
    fn human_line_includes_mark_and_diff() {
        let line = format_human_line(
            "case",
            &AssayOutcome::Fail {
                claim: "eq".into(),
                left: None,
                right: None,
                diff: "left != right".into(),
            },
        );
        assert!(line.starts_with("FAIL case"));
        assert!(line.contains("left != right"));
    }

    #[test]
    fn tap_line_ok_and_not_ok() {
        assert_eq!(
            format_tap_line(1, "ok_case", &AssayOutcome::Pass),
            "ok 1 - ok_case"
        );
        let not_ok = format_tap_line(
            2,
            "bad",
            &AssayOutcome::EvalError {
                kind: "throw".into(),
                message: "boom".into(),
                span: None,
            },
        );
        assert!(not_ok.starts_with("not ok 2 - bad"));
        assert!(not_ok.contains("boom"));
        let quiet = format_tap_line(
            3,
            "quiet",
            &AssayOutcome::EvalError {
                kind: "io".into(),
                message: String::new(),
                span: None,
            },
        );
        assert_eq!(quiet, "not ok 3 - quiet");
    }

    #[test]
    fn tap_line_other_outcome_variants() {
        assert!(format_tap_line(1, "r", &AssayOutcome::Recursion).contains("infinite recursion"));
        assert!(format_tap_line(1, "t", &AssayOutcome::Timeout).contains("timeout"));
        assert!(format_tap_line(1, "l", &AssayOutcome::ResourceLeak).contains("resource leak"));
        assert!(
            format_tap_line(
                1,
                "c",
                &AssayOutcome::Counterexample {
                    seed: 1,
                    shrunk: serde_json::json!(null),
                }
            )
            .contains("counterexample")
        );
        assert!(
            format_tap_line(
                1,
                "s",
                &AssayOutcome::SnapshotMismatch {
                    path: "golden.json".into(),
                    diff: "mismatch".into(),
                }
            )
            .contains("mismatch")
        );
    }

    #[test]
    fn outcome_stream_collect_preserves_order() {
        let outcomes = sample_outcomes();
        let collected = run_blocking(outcome_stream(&outcomes).run_collect(), ()).expect("collect");
        assert_eq!(collected.len(), 2);
        assert_eq!(collected[0].0, "passing");
        assert_eq!(collected[1].0, "failing");
    }

    #[test]
    fn collect_formatted_lines_human() {
        let outcomes = sample_outcomes();
        let lines = collect_formatted_lines(&outcomes, ReportFormat::Human);
        assert_eq!(lines.len(), 2);
        assert!(lines[0].body.starts_with("PASS"));
        assert!(lines[1].body.starts_with("FAIL"));
    }

    #[test]
    fn report_json_round_trip() {
        let outcomes = sample_outcomes();
        let summary = RunSummary {
            total: 2,
            passed: 1,
            failed: 1,
            errored: 0,
        };
        let mut buf = Vec::new();
        report_outcomes(&outcomes, ReportFormat::Json, &summary, &mut buf).unwrap();
        let text = String::from_utf8(buf).unwrap();
        let parsed: Vec<serde_json::Value> = serde_json::from_str(text.trim()).unwrap();
        assert_eq!(parsed.len(), 2);
        assert_eq!(parsed[0]["name"], "passing");
    }

    #[test]
    fn report_tap_includes_plan() {
        let outcomes = sample_outcomes();
        let summary = RunSummary {
            total: 2,
            passed: 1,
            failed: 1,
            errored: 0,
        };
        let mut buf = Vec::new();
        report_outcomes(&outcomes, ReportFormat::Tap, &summary, &mut buf).unwrap();
        let text = String::from_utf8(buf).unwrap();
        assert!(text.contains("TAP version 13"));
        assert!(text.contains("1..2"));
        assert!(text.contains("ok 1 - passing"));
        assert!(text.contains("not ok 2 - failing"));
    }

    #[test]
    fn print_lines_effect_runs() {
        let _ = run_blocking(
            print_lines_effect(vec![ReportLine {
                body: "line".into(),
            }]),
            (),
        );
    }

    #[test]
    fn succeed_effect_smoke() {
        let _ = run_blocking(succeed::<(), (), ()>(()), ());
    }
}
