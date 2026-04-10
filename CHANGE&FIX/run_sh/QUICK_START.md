# run.sh — Quick Guide (EN)

`run.sh` is a lightweight wrapper around `nextflow run` that helps you run the Riboseq workflow with consistent defaults, diagnostics, and log/result helpers.

## Quick start

```bash
chmod +x run.sh
./run.sh diagnose
./run.sh start
./run.sh logs-follow
```

## Prerequisites

- Nextflow available in your shell (recommended: `conda activate nextflow`)
- Docker running when using `RUNWAY=docker` (default)

## Commands

Run `./run.sh help` for the authoritative list. Most usage falls into:

```bash
./run.sh diagnose
./run.sh start|stop|restart|status
./run.sh logs|logs-follow|logs-error|logs-search <term>
./run.sh summary|report|results
```

## Configuration (environment variables)

`run.sh` reads these environment variables:

```bash
PIPELINE_DIR=./                   # default: ./
CONFIG_FILE=conf/test_local.config # default: conf/test_local.config
WORK_DIR=nextflow_work            # default: nextflow_work
RUNWAY=docker                     # default: docker (passed to -profile)
OUTDIR=results_testdata           # default: results_testdata (passed to --outdir)
EXTRA_ARGS=""                     # default: empty (appended to nextflow run)
```

Example:

```bash
PIPELINE_DIR="/path/to/pipeline" \
CONFIG_FILE="conf/my.config" \
RUNWAY="docker" \
OUTDIR="results" \
EXTRA_ARGS="--max_cpus 8" \
./run.sh start
```

## Typical workflows

```bash
./run.sh diagnose
./run.sh start
./run.sh logs-follow
```

```bash
./run.sh status
./run.sh logs-error
```

```bash
./run.sh summary
./run.sh report
./run.sh clean
```

## Troubleshooting

```bash
./run.sh diagnose
./run.sh check-config
./run.sh check-docker
./run.sh logs-error
```

If the pipeline did not start, check `nextflow.out` (startup output) and `.nextflow.log` (Nextflow log).

## Chinese documentation

See `run_sh/使用说明.md` for the Chinese version of this guide.

---

**Happy analyzing! 🧬🌾**

For issues, first run: `./run.sh diagnose`
