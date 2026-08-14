//! Errors for nix-hash.

#[derive(Debug, Clone, thiserror::Error, PartialEq, Eq)]
pub enum HashError {
    #[error("error: {message}")]
    Msg { message: String },

    #[error("error: reading file `{path}': {message}")]
    Io { path: String, message: String },

    #[error("error: {0}")]
    Nar(String),

    #[error("error: {0}")]
    Convert(String),
}

impl HashError {
    pub fn msg(message: impl Into<String>) -> Self {
        Self::Msg {
            message: message.into(),
        }
    }
}
