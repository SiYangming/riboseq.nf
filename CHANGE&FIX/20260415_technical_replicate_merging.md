# Technical Replicate Merging Feature

## Overview
Implemented automatic merging of technical replicates (e.g., R1, R2) for samples using the `nf-core/cat/fastq` module. The feature detects files with the same sample ID and concatenates them before downstream processing.

## Implementation Details

### 1. Workflow Architecture Change
- Instead of using a separate subworkflow, the technical replicate merging logic has been integrated natively into the `workflows/riboseq/main.nf` data loading step and `subworkflows/nf-core/fastq_qc_trim_filter_setstrandedness/main.nf`.
- `main.nf` now uses `.groupTuple()` after parsing the input samplesheet to aggregate FastQ files belonging to the same sample ID.

### 2. Workflow Integration
- **`CAT_FASTQ` in Subworkflow**: Inside `fastq_qc_trim_filter_setstrandedness`, the aggregated `ch_fastq` channel is branched into `single` (no replicates) and `multiple` (has replicates). The `multiple` branch is merged using `CAT_FASTQ`, and the results are mixed back together.
- **`UPDATE_SAMPLESHEET` Process**: Added a module that parses the original samplesheet, merges the `sample_description` for rows with identical `sample` IDs using a pipe separator (`|`), renames the original samplesheet to `samplesheet_original.csv`, and saves the updated one as `samplesheet.csv` in the input's original directory.
- Downstream tools like `QUANTIFY_STAR_SALMON` and `ANOTA2SEQ_ANOTA2SEQRUN` now utilize the updated `UPDATE_SAMPLESHEET.out.samplesheet` channel.
- Fixed `CAT_FASTQ` version emission bugs and corrected the Groovy `join` structure of `ch_filtered_reads` after the `FQ_LINT` step to maintain the expected `[meta, reads]` tuple format.

## Testing
- The implementation has been verified to correctly route single samples as-is while merging grouped samples seamlessly using the DSL2 channel operations. Memory allocation errors for indexing processes (like `SORTMERNA_INDEX`) were also patched during testing.
