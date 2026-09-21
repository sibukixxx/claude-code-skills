# Claude Code Skills Collection

Reusable Claude Code Skills and command definitions. Skill files are the product; examples/docs must match their actual invocation contracts.

## Commands
- Validate changed scripts/Skill files with the repository's existing test/lint scripts when defined.
- For shell/install changes, run the installer in a disposable/local path rather than overwriting unrelated user configuration.

## Shared rules
- One Skill owns one detailed workflow; do not copy the same procedure into root agent instructions.
- Keep Skill metadata, paths, command names, and referenced files internally consistent.
- Installation must not overwrite existing user files without the repository's documented merge/backup behavior.
- Examples must use currently supported paths/commands; remove stale model/version assumptions from reusable templates.
- Never package secrets, machine-specific absolute paths, or private workspace content into reusable Skills.

## Change-dependent checks
- Skill change: verify every referenced file/script exists and execute its deterministic validation path.
- Installer/layout change: test install/update behavior against a disposable directory.
- Command examples: run or syntax-check representative examples.

## Done
- Changed Skill is self-contained and its references resolve.
- Installation remains non-destructive according to the repository contract.
- No machine-specific/private state is embedded.
