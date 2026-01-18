#!/usr/bin/env python3
"""
Download rRNA databases for SortMeRNA
Downloads files to the reference/ directory if they don't exist
"""

import os
import sys
import urllib.request
from pathlib import Path

# Define the reference directory (relative to project root)
SCRIPT_DIR = Path(__file__).parent.resolve()
PROJECT_ROOT = SCRIPT_DIR.parent
REFERENCE_DIR = PROJECT_ROOT / "reference"

# List of rRNA database URLs
DATABASES = [
    "https://raw.githubusercontent.com/biocore/sortmerna/v4.3.4/data/rRNA_databases/rfam-5.8s-database-id98.fasta",
    "https://raw.githubusercontent.com/biocore/sortmerna/v4.3.4/data/rRNA_databases/rfam-5s-database-id98.fasta",
    "https://raw.githubusercontent.com/biocore/sortmerna/v4.3.4/data/rRNA_databases/silva-arc-16s-id95.fasta",
    "https://raw.githubusercontent.com/biocore/sortmerna/v4.3.4/data/rRNA_databases/silva-arc-23s-id98.fasta",
    "https://raw.githubusercontent.com/biocore/sortmerna/v4.3.4/data/rRNA_databases/silva-bac-16s-id90.fasta",
    "https://raw.githubusercontent.com/biocore/sortmerna/v4.3.4/data/rRNA_databases/silva-bac-23s-id98.fasta",
    "https://raw.githubusercontent.com/biocore/sortmerna/v4.3.4/data/rRNA_databases/silva-euk-18s-id95.fasta",
    "https://raw.githubusercontent.com/biocore/sortmerna/v4.3.4/data/rRNA_databases/silva-euk-28s-id98.fasta",
]


def download_file(url, filepath):
    """Download a file from URL to filepath with progress indication"""
    try:
        print(f"⬇ Downloading {filepath.name}...", end=" ", flush=True)
        urllib.request.urlretrieve(url, filepath)
        print("✓")
        return True
    except Exception as e:
        print(f"✗ Failed: {e}")
        if filepath.exists():
            filepath.unlink()  # Remove partial download
        return False


def main():
    # Create reference directory if it doesn't exist
    REFERENCE_DIR.mkdir(parents=True, exist_ok=True)
    
    print("=" * 50)
    print(f"Downloading rRNA databases to: {REFERENCE_DIR}")
    print("=" * 50)
    
    # Download each database if it doesn't exist
    all_success = True
    for url in DATABASES:
        filename = Path(url).name
        filepath = REFERENCE_DIR / filename
        
        if filepath.exists():
            print(f"✓ {filename} already exists, skipping download")
        else:
            if not download_file(url, filepath):
                all_success = False
                break
    
    if not all_success:
        print("\n✗ Failed to download all databases")
        sys.exit(1)
    
    print("=" * 50)
    print(f"✓ All rRNA databases ready in {REFERENCE_DIR}")
    print("=" * 50)
    
    # Create a custom rRNA database manifest file pointing to local files
    manifest_file = REFERENCE_DIR / "rrna-db-local.txt"
    print(f"\nCreating local database manifest: {manifest_file}")
    
    with open(manifest_file, 'w') as f:
        for url in DATABASES:
            filename = Path(url).name
            f.write(f"{REFERENCE_DIR}/{filename}\n")
    
    print(f"✓ Created manifest file: {manifest_file}")
    print("\nTo use these local databases, add to your nextflow.config:")
    print(f"params.ribo_database_manifest = '{manifest_file}'")
    print("\nOr use the command line option:")
    print(f"--ribo_database_manifest {manifest_file}")


if __name__ == "__main__":
    main()
