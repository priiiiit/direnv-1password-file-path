# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Migrated from direnv to mise as the environment manager
- Temp file prefix changed from `direnv-` to `op-secret-`
- PID detection now walks the process tree to find the interactive shell instead of relying on `DIRENV_PARENT_PID`
- Installation via shell sourcing or mise `env._source` instead of direnv `source_url`

### Added
- `OP_SECRET_SHELL_PID` env var override for manual PID control
- `_op_secret_find_shell_pid()` helper for robust interactive shell detection
