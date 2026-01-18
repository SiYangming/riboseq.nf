#!/usr/bin/env bash
set -euo pipefail

# Script to download rRNA databases for SortMeRNA
# Downloads files to the reference/ directory if they don't exist

# Define the reference directory (relative to project root)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"
REFERENCE_DIR="${PROJECT_ROOT}/reference"

# Create reference directory if it doesn't exist
mkdir -p "${REFERENCE_DIR}"

# List of rRNA database URLs
DATABASES=(
    "https://raw.githubusercontent.com/biocore/sortmerna/v4.3.4/data/rRNA_databases/rfam-5.8s-database-id98.fasta"
    "https://raw.githubusercontent.com/biocore/sortmerna/v4.3.4/data/rRNA_databases/rfam-5s-database-id98.fasta"
    "https://raw.githubusercontent.com/biocore/sortmerna/v4.3.4/data/rRNA_databases/silva-arc-16s-id95.fasta"
    "https://raw.githubusercontent.com/biocore/sortmerna/v4.3.4/data/rRNA_databases/silva-arc-23s-id98.fasta"
    "https://raw.githubusercontent.com/biocore/sortmerna/v4.3.4/data/rRNA_databases/silva-bac-16s-id90.fasta"
    "https://raw.githubusercontent.com/biocore/sortmerna/v4.3.4/data/rRNA_databases/silva-bac-23s-id98.fasta"
    "https://raw.githubusercontent.com/biocore/sortmerna/v4.3.4/data/rRNA_databases/silva-euk-18s-id95.fasta"
    "https://raw.githubusercontent.com/biocore/sortmerna/v4.3.4/data/rRNA_databases/silva-euk-28s-id98.fasta"
)

echo "=========================================="
echo "Downloading rRNA databases to: ${REFERENCE_DIR}"
echo "=========================================="

# Download each database if it doesn't exist
for url in "${DATABASES[@]}"; do
    filename=$(basename "${url}")
    filepath="${REFERENCE_DIR}/${filename}"
    
    if [ -f "${filepath}" ]; then
        echo "✓ ${filename} already exists, skipping download"
    else
        echo "⬇ Downloading ${filename}..."
        if wget -q --show-progress -O "${filepath}" "${url}"; then
            echo "✓ Successfully downloaded ${filename}"
        else
            echo "✗ Failed to download ${filename}"
            rm -f "${filepath}"  # Remove partial download
            exit 1
        fi
    fi
done

echo "=========================================="
echo "✓ All rRNA databases ready in ${REFERENCE_DIR}"
echo "=========================================="

# Create a custom rRNA database manifest file pointing to local files
MANIFEST_FILE="${REFERENCE_DIR}/rrna-db-local.txt"
echo "Creating local database manifest: ${MANIFEST_FILE}"

> "${MANIFEST_FILE}"  # Clear/create file
for url in "${DATABASES[@]}"; do
    filename=$(basename "${url}")
    echo "${REFERENCE_DIR}/${filename}" >> "${MANIFEST_FILE}"
done

echo "✓ Created manifest file: ${MANIFEST_FILE}"
echo ""
echo "To use these local databases, add to your nextflow.config:"
echo "params.ribo_database_manifest = '${REFERENCE_DIR}/rrna-db-local.txt'"
