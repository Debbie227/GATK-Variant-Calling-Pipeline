#!/usr/bin/env nextflow


workflow {

    reads_ch = Channel.of(params.sample)

    reads_ch | DOWNLOAD_FASTQ | FILTER_FASTQ | FASTQC | TRIM

}


process DOWNLOAD_FASTQ {
    input:
    val sample

    output:
    tuple val(sample), 
    path("${sample}_1.fastq.gz"), 
    path("${sample}_2.fastq.gz")

    script:
    """
    gcloud storage cp gs://${params.bucket}/${sample}_*.fastq.gz .
    """
}

process FILTER_FASTQ {
    input:
    tuple val(sample), path(r1), path(r2)

    output:
    tuple val(sample), 
        path("match_${sample}_1.fastq.gz"), 
        path("match_${sample}_2.fastq.gz")

    script:
    """
    fastq_filterpair \
        $r1 $r2 \
        match_${sample}_1.fastq.gz match_${sample}_2.fastq.gz \
        ${sample}_single.fastq.gz
    """
}

process FASTQC {

    publishDir 'gs://gatk-resource-bucket/nextflow-results/', 
                mode: 'copy',
                pattern: "*.{html,zip}"

    input:
    tuple val(sample), 
    path(r1), 
    path(r2)

    output:
    tuple val(sample), 
    path(r1), 
    path(r2)

    script:
    """
    fastqc $r1 $r2
    """
}

process TRIM {
    input:
    tuple val(sample), path(r1), path(r2)

    output:
    tuple val(sample),
        path("${sample}_1_val_1.fq.gz"),
        path("${sample}_2_val_2.fq.gz")

    script:
    """
    trim_galore --paired --quality 20 --length 50 $r1 $r2
    """
}
