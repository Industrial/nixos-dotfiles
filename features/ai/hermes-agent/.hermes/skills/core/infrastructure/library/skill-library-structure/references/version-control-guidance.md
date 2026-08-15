# Version Control Guidance for Hermes Skills

## What to Include in Version Control

When managing Hermes skills and configuration in a Git repository:

### ✅ Include (Version Control These)
- Skill definition files: `SKILL.md`
- Custom skills you've created
- Plugin implementations and configurations
- Memory files (`MEMORY.md`, `USER.md`) if you want to persist them
- Cron job definitions
- Hermes configuration: `config.yaml`
- `.env.example` (template, not actual `.env` with secrets)
- Skill references, templates, and scripts directories

### ❌ Exclude (Do NOT Version Control)
Add these to your `.gitignore`:
- Runtime/cache directories:
  ```
  .hermes/sessions/
  .hermes/logs/
  .hermes/cache/
  .hermes/image_cache/
  .hermes/audio_cache/
  ```
- Database and cache files:
  ```
  *.db
  *.db-shm
  *.db-wal
  *.log
  .hermes_history
  state.db
  state.db-shm
  state.db-wal
  verification_evidence.db
  models_dev_cache.json
  provider_models_cache.json
  ollama_cloud_models_cache.json
  ```
- Temporary and lock files:
  ```
  *.lock
  auth.lock
  processes.json
  interrupt_debug.log
  .update_check
  ```
- Environment files with actual secrets:
  ```
  .env
  ```
- Sandboxes and pairing data:
  ```
  .hermes/sandboxes/
  .hermes/pairing/
  ```
- Hooks and internal state:
  ```
  .hermes/hooks/
  .hermes/.curator_*  # Unless you specifically want to backup curator state
  ```

## Recommended .gitignore Additions

Add these lines to your repository's `.gitignore`:

```
# Hermes runtime/cache data - DO NOT VERSION CONTROL
.hermes/sessions/
.hermes/logs/
.hermes/cache/
.hermes/image_cache/
.hermes/audio_cache/
.hermes/pastes/
*.db
*.db-shm
*.db-wal
*.log
.hermes_history
state.db
state.db-shm
state.db-wal
verification_evidence.db
models_dev_cache.json
provider_models_cache.json
ollama_cloud_models_cache.json
*.lock
auth.lock
processes.json
interrupt_debug.log
.update_check
.env
.hermes/sandboxes/
.hermes/pairing/
.hermes/hooks/
```

## Skipping Pre-Push Hooks When Needed

If you need to temporarily bypass the deepsec pre-push hook (for example, when pushing large binary files you know are safe):

```bash
DEEPSEC_PRE_PUSH_SKIP=1 git push
```

Or to use a different agent for deepsec analysis:

```bash
DEEPSEC_PRE_PUSH_AGENT=codex git push
```

## Setting Up a New Clone

When cloning the repository to a new machine:

1. The skills, plugins, memories, and config will be available
2. Run `hermes setup` to initialize directories and check configuration
3. Cache directories and runtime files will be created fresh on first use
4. If you excluded `.env`, copy `.env.example` to `.env` and fill in your secrets

This approach keeps your repository lightweight, shareable, and free of machine-specific runtime data while preserving your customizations and configuration.