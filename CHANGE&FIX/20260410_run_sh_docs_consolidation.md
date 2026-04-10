# run_sh Documentation Consolidation - 2026-04-10

## Summary
Consolidated the `run_sh/` documentation into exactly two files (English + Chinese) and removed redundant/overlapping documents. Updated `run.sh help` to point to the new doc locations.

## Modified Files

### Documentation
- [QUICK_START.md](file:///Users/siyangming/nextflow_nf_core/riboseq.nf/run_sh/QUICK_START.md)
  - Rewritten as the single English guide (quick start, configuration, workflows, troubleshooting).
- [使用说明.md](file:///Users/siyangming/nextflow_nf_core/riboseq.nf/run_sh/使用说明.md)
  - Rewritten as the single Chinese guide (mirrors the English guide, with defaults aligned to `run.sh`).

### Script
- [run.sh](file:///Users/siyangming/nextflow_nf_core/riboseq.nf/run.sh)
  - Updated the help footer to reference `run_sh/QUICK_START.md` (EN) and `run_sh/使用说明.md` (中文).

### Deleted (no longer needed)
- `run_sh/00_README_START_HERE.md`
- `run_sh/README_run_sh.md`
- `run_sh/FILES_SUMMARY.txt`
- `run_sh/更新总结.md`

## Verification
- Confirmed `run_sh/` contains only `QUICK_START.md` and `使用说明.md`.
- Searched the repository for references to the deleted files and found no matches.
