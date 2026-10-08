#!/usr/bin/env bash

###############################################################################
# Setup script for rRNA databases
# This script should be run from your actual server at:
# /data1/users/siyangming/nextflow_nf_core/riboseq.nf/
###############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=========================================="
echo "rRNA Database Setup Script"
echo -e "==========================================${NC}"
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( dirname "${SCRIPT_DIR}" )"
echo -e "${YELLOW}Project directory:${NC} ${PROJECT_ROOT}"

# Define paths (align with Python helper script)
REFERENCE_DIR="${PROJECT_ROOT}/reference"
BIN_DIR="${SCRIPT_DIR}"
MANIFEST_FILE="${REFERENCE_DIR}/rrna-db-local.txt"

echo -e "${YELLOW}Reference directory:${NC} ${REFERENCE_DIR}"
echo ""

# Check if reference directory exists
if [ ! -d "${REFERENCE_DIR}" ]; then
    echo -e "${YELLOW}Creating reference directory...${NC}"
    mkdir -p "${REFERENCE_DIR}"
fi

# Check for Python
if command -v python3 &> /dev/null; then
    echo -e "${GREEN}✓ Python3 found${NC}"
    PYTHON_AVAILABLE=true
else
    echo -e "${RED}✗ Python3 not found${NC}"
    PYTHON_AVAILABLE=false
fi

# Check for wget
if command -v wget &> /dev/null; then
    echo -e "${GREEN}✓ wget found${NC}"
    WGET_AVAILABLE=true
else
    echo -e "${RED}✗ wget not found${NC}"
    WGET_AVAILABLE=false
fi

echo ""

# Run the appropriate download script
if [ "$PYTHON_AVAILABLE" = true ]; then
    echo -e "${GREEN}Running Python download script...${NC}"
    python3 "${BIN_DIR}/download_rrna_databases.py"
elif [ "$WGET_AVAILABLE" = true ]; then
    echo -e "${GREEN}Running bash download script...${NC}"
    bash "${BIN_DIR}/download_rrna_databases.sh"
else
    echo -e "${RED}ERROR: Neither Python3 nor wget is available!${NC}"
    echo "Please install one of them and try again."
    exit 1
fi

# Verify the manifest file was created
if [ -f "${MANIFEST_FILE}" ]; then
    echo ""
    echo -e "${GREEN}=========================================="
    echo "✓ Setup Complete!"
    echo -e "==========================================${NC}"
    echo ""
    echo -e "${YELLOW}Manifest file created:${NC}"
    echo "${MANIFEST_FILE}"
    echo ""
    echo -e "${YELLOW}Downloaded databases ($(ls -1 ${REFERENCE_DIR}/*.fasta 2>/dev/null | wc -l) files):${NC}"
    ls -lh "${REFERENCE_DIR}"/*.fasta 2>/dev/null | awk '{print "  - " $9 " (" $5 ")"}'
    echo ""
    echo -e "${YELLOW}Total size:${NC}"
    du -sh "${REFERENCE_DIR}"
    echo ""
    echo -e "${GREEN}Next steps:${NC}"
    echo "1. Update your nextflow.config with:"
    echo -e "   ${YELLOW}params.ribo_database_manifest = '${MANIFEST_FILE}'${NC}"
    echo ""
    echo "2. Or use the provided fixed config:"
    echo -e "   ${YELLOW}nextflow run . -c osa_config_FIXED.config${NC}"
    echo ""
else
    echo -e "${RED}ERROR: Manifest file was not created!${NC}"
    echo "Please check the error messages above."
    exit 1
fi
