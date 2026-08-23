User prefers using 'hermes config set' for individual configuration changes rather than direct file edits due to security restrictions that block direct modifications to sensitive settings.
§
User appreciates when agents archive significant work products (like plans) with timestamps in a history/ directory for future reference, as demonstrated in the Assay planning session.
§
Values concise direct responses and verification of changes; prefers NixOS work without Home Manager; likes class-level skill organization; expects default.nix + assay test files added together.
§
NixOS fleet: reuse existing modules in features/media/ and features/monitoring/ rather than creating new ones; persistent state at /mnt/well/services/<name>.
§
Andromeda paper bot = live ops: watchdog cron on long sessions; 'analyze/report only' forbids restarts/kills/code changes; claims need TDD RED→GREEN + real-execution evidence; ledgers under repo history/.
§
Hermes skill-name collision: bare skill_view('id-workflow') is refused as ambiguous (exists at core/id-workflow AND core/utilities/workflow/id-workflow) — load by full path 'core/id-workflow'.
§
User prefers mermaid diagrams in markdown docs — never ASCII box art. Flowcharts for layer maps, sequence diagrams for traces. See skill: documentation/architecture-doc-authoring.