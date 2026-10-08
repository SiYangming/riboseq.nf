# Kallisto Pseudo-alignment Integration - 2026-01-29

## Summary
Integrated **Kallisto** as an alternative pseudo-alignment tool to Salmon. The pipeline now supports conditional execution of either Salmon or Kallisto for quantification based on the `--pseudo_aligner` parameter.

## Modified Files

### 1. Configuration & Parameters
- **`nextflow.config`**:
  - Added default parameters:
    - `extra_kallisto_quant_args = null`
    - `kallisto_quant_fraglen = null` (Required for single-end data)
    - `kallisto_quant_fraglen_sd = null` (Required for single-end data)
    - `kallisto_index = null`
- **`nextflow_schema.json`**:
  - Added parameter definitions, type validation (number/path), and descriptions for all new Kallisto parameters.
- **`conf/modules.config`**:
  - Configured `publishDir` for `KALLISTO_INDEX` (`genome/index`) and `KALLISTO_QUANT` (`quantification/kallisto`).
  - Updated `TXIMETA_TXIMPORT` and `SE_*` (SummarizedExperiment) modules to use dynamic paths (`${params.outdir}/quantification/${params.pseudo_aligner}`) and filenames to avoid overwriting Salmon outputs.

### 2. Workflow Logic
- **`subworkflows/local/prepare_genome/main.nf`**:
  - Added input channel `kallisto_index`.
  - Implemented logic to:
    - Uncompress provided `kallisto_index` (tar.gz).
    - Or generate index using `KALLISTO_INDEX` module if `params.pseudo_aligner == 'kallisto'`.
  - Exported `kallisto_index` channel.
- **`subworkflows/nf-core/quantify_pseudo_alignment/main.nf`**:
  - Updated input channels to accept `kallisto_quant_fraglen` and `kallisto_quant_fraglen_sd`.
  - Added conditional execution:
    - If `pseudo_aligner == 'salmon'`: Run `SALMON_QUANT`.
    - If `pseudo_aligner == 'kallisto'`: Run `KALLISTO_QUANT`.
  - Standardized output channels (`ch_pseudo_results`, `ch_pseudo_multiqc`) to ensure downstream compatibility with `TXIMPORT` and `MULTIQC`.
- **`workflows/riboseq/main.nf`**:
  - Passed `params.kallisto_index` to `PREPARE_GENOME`.
  - Updated `QUANTIFY_STAR_SALMON` (subworkflow call) to pass the new Kallisto-related channels and parameters.

### 3. Documentation
- **`docs/output.md`**:
  - Generalized the "Quantification" section to use `<PSEUDO_ALIGNER>` placeholders instead of hardcoded "salmon".
  - Added specific file descriptions for Kallisto outputs (`abundance.h5`, `abundance.tsv`, etc.).

## Verification
- Confirmed that Kallisto outputs are saved to `quantification/kallisto` and do not conflict with `quantification/salmon`.
- Verified parameter passing for single-end data requirements.
