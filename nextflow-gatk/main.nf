#!/usr/bin/env nextflow

params.sample = params.sample ?: "SRR12023503"

Channel
    .of(params.sample)
    .set { samples }

process DOWNLOAD_FASTQ {
    input:
    val sample from samples

    output:
    tuple val(sample), 
    path("${sample}_1.fastq.gz"), 
    path("${sample}_2.fastq.gz")

    script:
    """
    gcloud storage cp gs://${params.bucket}/${sample}_*.fastq.gz .
    """
}

process TRIM_QC {
    input:
    tuple val(sample), path(r1), path(r2)

    output:
    tuple val(sample),
        path("${sample}_1_val_1.fq.gz"),
        path("${sample}_2_val_2.fq.gz")

    script:
    """
    fastqc $r1 $r2

    trim_galore --paired --quality 20 --length 50 $r1 $r2
    """
}