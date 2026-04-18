process UPDATE_SAMPLESHEET {
    label 'process_single'

    conda "conda-forge::python=3.9.5"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'quay.io/biocontainers/python:3.9--1' }"
    
    // Publish to the same directory as the original input file
    publishDir "${file(params.input).getParent() ?: '.'}", mode: 'copy', overwrite: true

    input:
    path original_samplesheet
    val reads_ready // to ensure it runs after MERGE_TECH_REPLICATES

    output:
    path "samplesheet.csv", emit: samplesheet
    path "samplesheet_original.csv", emit: original

    script:
    """
    #!/usr/bin/env python3
    import csv
    import shutil
    import os

    input_file = '${original_samplesheet}'
    outdir = '${file(params.outdir).toAbsolutePath()}'
    
    # Backup the original
    shutil.copy(input_file, 'samplesheet_original.csv')

    # Read original
    with open(input_file, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        rows = list(reader)

    # Group by sample and aggregate
    grouped = {}
    counts = {}
    for row in rows:
        sample = row['sample']
        if sample not in grouped:
            grouped[sample] = row.copy()
            counts[sample] = 1
            # Initialize description list
            if 'sample_description' in row and row['sample_description']:
                grouped[sample]['_desc_list'] = [row['sample_description']]
            else:
                grouped[sample]['_desc_list'] = []
        else:
            counts[sample] += 1
            # Combine sample_description
            if 'sample_description' in row and row['sample_description']:
                desc = row['sample_description']
                if desc not in grouped[sample]['_desc_list']:
                    grouped[sample]['_desc_list'].append(desc)
    
    # Write the new samplesheet
    with open('samplesheet.csv', 'w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for sample, data in grouped.items():
            if '_desc_list' in data:
                data['sample_description'] = ' | '.join(data['_desc_list'])
                del data['_desc_list']
            
            # Update fastq paths if the sample was merged (count > 1)
            if counts[sample] > 1:
                is_paired = bool(data.get('fastq_2'))
                if is_paired:
                    data['fastq_1'] = os.path.join(outdir, 'fastq', f"{sample}_1.merged.fastq.gz")
                    data['fastq_2'] = os.path.join(outdir, 'fastq', f"{sample}_2.merged.fastq.gz")
                else:
                    data['fastq_1'] = os.path.join(outdir, 'fastq', f"{sample}.merged.fastq.gz")
                    data['fastq_2'] = ""

            writer.writerow(data)
    """
}
