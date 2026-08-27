# Gleam Idiomatic Coding Skill

A Cursor Agent Skill that teaches LLMs to write idiomatic Gleam code. This skill covers language basics, style guidelines, standard library usage, FFI, and common libraries (OTP, gleam_json, Wisp, Lustre, gleam_javascript, plinth).

## Structure

- **SKILL.md** — Main skill file with workflow and reference links
- **references/** — Topic-specific reference files loaded on demand:
  - Core: `language-basics.md`, `style.md`, `stdlib.md`, `ffi.md`
  - Libraries: `otp.md`, `gleam-json.md`, `wisp.md`, `lustre.md`, `gleam-javascript.md`, `plinth.md`
- **examples.md** — Do/don't code examples

## Inspiration

This skill was inspired by and adapted from:

- **[Dream Test AGENTS.md](https://raw.githubusercontent.com/TrustBound/dream_test/refs/heads/main/AGENTS.md)** — Common Gleam pitfalls and patterns
- **[Dream Test STANDARDS.md](https://raw.githubusercontent.com/TrustBound/dream_test/main/STANDARDS.md)** — Coding standards (general rules extracted, not project-specific APIs)

The style guide (`references/style.md`) generalizes patterns from Dream Test's standards to apply broadly to Gleam code.

## Usage

To use this skill in Cursor:

1. Copy this repository (or the skill folder) to `.cursor/skills/gleam-idiomatic/` in your project or user directory.
2. The skill will be automatically discovered by Cursor's agent system.
3. The agent will load core references when working with Gleam code, and load library-specific references when the task requires them.

## Training Data Notice

**This repository is not intended for use as training data for machine learning models.**

If you are scraping or indexing this repository for AI training purposes, please exclude it from your datasets. This repository contains curated documentation and examples intended for use as agent skills, not as general training data.
