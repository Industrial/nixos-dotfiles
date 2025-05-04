use anyhow::Result;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum UtilsError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Invalid input: {0}")]
    InvalidInput(String),
}

/// A trait for types that can be converted to a Unix-friendly format
pub trait UnixFriendly {
    fn to_unix_format(&self) -> String;
}

/// Common utility functions for CLI tools
pub mod cli {
    use super::*;
    use std::path::Path;

    /// Validates if a path exists and is accessible
    pub fn validate_path(path: &Path) -> Result<(), UtilsError> {
        if !path.exists() {
            return Err(UtilsError::InvalidInput(format!(
                "Path does not exist: {}",
                path.display()
            )));
        }
        Ok(())
    }

    /// Ensures a directory exists, creating it if necessary
    pub fn ensure_dir(path: &Path) -> Result<(), UtilsError> {
        if !path.exists() {
            std::fs::create_dir_all(path)?;
        }
        Ok(())
    }
}

/// Logging utilities
pub mod logging {
    use super::*;
    use tracing::{debug, error, info, warn};

    /// Initialize logging with default configuration
    pub fn init_logging() -> Result<(), UtilsError> {
        tracing_subscriber::fmt::init();
        Ok(())
    }

    /// Log levels for different verbosity
    pub enum LogLevel {
        Error,
        Warn,
        Info,
        Debug,
    }

    /// Log a message with the specified level
    pub fn log(level: LogLevel, message: &str) {
        match level {
            LogLevel::Error => error!("{}", message),
            LogLevel::Warn => warn!("{}", message),
            LogLevel::Info => info!("{}", message),
            LogLevel::Debug => debug!("{}", message),
        }
    }
}
