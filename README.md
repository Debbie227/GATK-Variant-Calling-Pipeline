# GATK Variant Calling Pipeline

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A523.04.0-23aa62.svg)](https://www.nextflow.io/)
[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=flat&logo=docker&logoColor=white)](https://www.docker.com/)
[![Pixi](https://img.shields.io/badge/pixi-%23fcb045.svg)](https://pixi.sh/)
[![GATK](https://img.shields.io/badge/GATK-4.6.2.0-blue)](https://gatk.broadinstitute.org/)

A comprehensive, reproducible bioinformatics pipeline for germline variant calling using the Genome Analysis Toolkit (GATK) best practices. This project demonstrates multiple workflow implementations including bash scripting, Nextflow, and cloud deployment.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Technologies](#technologies)
- [Architecture](#architecture)
- [Installation](#installation)
- [Usage](#usage)
- [Project Structure](#project-structure)
- [Results](#results)
- [License](#license)

## 🎯 Overview

This project implements a complete GATK variant calling pipeline that processes raw FASTQ sequencing data through quality control, alignment, variant calling, filtering, and annotation. The pipeline follows GATK's recommended best practices for germline variant discovery and includes multiple deployment options for different use cases. 

### Key Capabilities Demonstrated

- **Bioinformatics Pipeline Development**: End-to-end variant calling workflow
- **Reproducible Environments**: Pixi-based dependency management
- **Workflow Orchestration**: Nextflow DSL2 implementation
- **Cloud Computing**: Google Cloud Platform deployment
- **Containerization**: Docker-based execution
- **Quality Control**: Comprehensive QC metrics and reporting

## ✨ Features

### Pipeline Steps
1. **Quality Control**: FastQC analysis of raw reads
2. **Adapter Trimming**: Trim Galore for Illumina adapter removal
3. **Read Alignment**: BWA-MEM alignment to reference genome
4. **BAM Processing**: Sorting, duplicate marking, and indexing
5. **Base Quality Score Recalibration**: GATK BQSR for systematic error correction
6. **Variant Calling**: HaplotypeCaller in GVCF mode
7. **Genotyping**: GVCF to VCF conversion
8. **Variant Filtering**: Hard filtering for SNPs and indels
9. **Functional Annotation**: SnpEff for variant effect prediction
10. **Statistics & Visualization**: Comprehensive reporting and BED files

### Multiple Implementation Options
- **Bash Script**: Traditional shell-based workflow with Pixi environment
- **Nextflow**: Scalable workflow orchestration (in development)
- **Cloud Deployment**: Docker container with Google Cloud Batch

## 🛠 Technologies

### Core Bioinformatics Tools
- **GATK 4.6.2.0**: Genome Analysis Toolkit for variant calling
- **BWA 0.7.19**: Burrows-Wheeler Aligner for read mapping
- **Samtools 1.23**: BAM file manipulation and analysis
- **FastQC 0.12.1**: Quality control for sequencing data
- **Trim Galore 0.6.5**: Adapter trimming and quality filtering
- **SnpEff 5.2**: Variant annotation and effect prediction
- **BCFtools 1.21**: VCF manipulation and statistics

### Workflow Management
- **Nextflow**: Workflow orchestration and scalability
- **Pixi**: Fast, reproducible package management
- **Docker**: Containerization for deployment
- **Google Cloud Batch**: Cloud execution environment

### Programming & Scripting
- **Bash**: Shell scripting for pipeline automation
- **Python**: Data processing and analysis scripts
- **R**: Statistical analysis and visualization

## 🏗 Architecture

```
Raw FASTQ ── QC ── Trimming ── Alignment ── Processing ── BQSR ── Calling ── Filtering ── Annotation ── Results
     │         │        │          │           │          │        │         │          │           │
     └─────────┴────────┴──────────┴───────────┴──────────┴────────┴─────────┴──────────┴───────────┘
                                               GATK Best Practices Pipeline
```

### Implementation Variants

#### 1. Bash Workflow (`gatk-variant-pipeline/`)
- Traditional shell commands with 16-step GATK pipeline
- Pixi environment for reproducible dependencies
- Local execution with comprehensive logging

#### 2. Nextflow Workflow (`nextflow-gatk/`)
- DSL2 syntax for modular, scalable workflows
- Process-based execution with automatic dependency resolution
- Cloud-native design with Google Cloud Storage integration

#### 3. Cloud Deployment (`cloud-gatk/`)
- Docker containerization for portability
- Google Cloud Batch for scalable execution
- Conda-lock for reproducible environments

## 🚀 Installation

### Prerequisites
- Linux/macOS environment
- Git
- Docker (for cloud deployment)
- Google Cloud SDK (for cloud features)

### Quick Start with Pixi

```bash
# Clone the repository
git clone https://github.com/Debbie227/GATK-Variant-Calling-Pipeline.git
cd GATK-Variant-Calling-Pipeline

# Navigate to bash workflow
cd gatk-variant-pipeline

# Install Pixi (if not already installed)
curl -fsSL https://pixi.sh/install.sh | bash
source ~/.bashrc

# Install dependencies
pixi install

# Copy configuration files
cp pixi.toml.example pixi.toml  # If needed
```

### Cloud Deployment Setup

```bash
# Navigate to cloud deployment
cd ../cloud-gatk

# Build Docker image
docker build -t gatk-pipeline .

# Or use Google Cloud Build
gcloud builds submit --tag gcr.io/YOUR-PROJECT/gatk-pipeline:latest
```

## 📖 Usage

### Bash Pipeline Execution

```bash
# Set sample name
SAMPLE="SRR12023503"

# Run individual commands from bash_commands.md
pixi run fastqc data/${SAMPLE}_R1.fastq.gz data/${SAMPLE}_R2.fastq.gz
pixi run bwa mem reference/genome.fasta data/${SAMPLE}_R1.fastq.gz data/${SAMPLE}_R2.fastq.gz > aligned/${SAMPLE}.sam
```

### Nextflow Pipeline (Development)

```bash
cd nextflow-gatk

# Run with local executor
nextflow run main.nf -profile local

# Run with Docker
nextflow run main.nf -profile docker

# Run on Google Cloud
nextflow run main.nf -profile gcp
```

### Cloud Batch Submission

```bash
# Submit job to Google Cloud Batch
gcloud batch jobs submit gatk-job \
    --location us-central1 \
    --config job.json
```

## 📁 Project Structure

```
GATK-Variant-Calling-Pipeline/
├── gatk-variant-pipeline/          # Bash workflow implementation
│   ├── pixi.toml                  # Environment dependencies
│   ├── bash_commands.md           # Setup and usage commands
│   ├── dockerfile                 # Local Docker build
│   ├── results/                   # Pipeline outputs
│   │   ├── qc/                    # Quality control reports
│   │   ├── aligned/               # BAM files and metrics
│   │   └── var/                   # VCF files and annotations
│   └── README.md                  # Bash workflow documentation
├── nextflow-gatk/                 # Nextflow workflow implementation
│   ├── main.nf                    # Main Nextflow script
│   ├── gatk.nf                    # GATK processes
│   ├── nextflow.config            # Configuration
│   ├── params.config              # Parameters
│   ├── docker-compose.yaml        # Local development
│   └── README.md                  # Nextflow documentation
├── cloud-gatk/                    # Cloud deployment
│   ├── variant-pipeline.sh        # Cloud-optimized script
│   ├── Dockerfile                 # Cloud container
│   ├── environment.yaml           # Conda environment
│   ├── conda-lock.yml             # Locked dependencies
│   ├── job.json                   # Cloud Batch configuration
│   └── README.md                  # Cloud deployment docs
└── README.md                      # This file
```

## 📊 Results

The pipeline generates comprehensive outputs for downstream analysis:

### Quality Control
- FastQC reports (HTML/PDF)
- Alignment summary metrics
- Insert size distributions
- Duplicate metrics

### Variant Calling
- Raw GVCF files
- Filtered VCF (SNPs + Indels)
- Annotated VCF with functional predictions
- Variant statistics and counts

### Visualization Files
- BED files for genomic regions
- BEDGraph files for coverage depth
- Summary statistics tables

Example output structure:
```
results/
├── qc/
│   ├── SRR12023503_alignment_summary.txt
│   └── SRR12023503_insert_size_metrics.txt
├── aligned/
│   ├── SRR12023503_recalibrated.bam
│   └── SRR12023503_recal_data.table
└── var/
    ├── SRR12023503_filtered.vcf.gz
    ├── SRR12023503_annotated.vcf
    └── SRR12023503_variant_stats.txt
```

## 🔧 Development

### Adding New Features
1. Update the bash script in `gatk_pipeline.sh`
2. Add corresponding Nextflow processes in `gatk.nf`
3. Update Pixi dependencies in `pixi.toml`
4. Test locally before cloud deployment

### Testing
```bash
# Run pipeline tests
pixi run pytest

# Validate VCF outputs
pixi run bcftools stats results/var/*.vcf.gz

# Check pipeline logs
tail -f logs/pipeline_*.log
```

### Environment Management
```bash
# Update dependencies
pixi add <new-package>

# Export environment
pixi export environment.yaml

# Create lock file
pixi install --lock
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Broad Institute for GATK and reference datasets
- Nextflow community for workflow inspiration
- Pixi project for reproducible environments
- Google Cloud for cloud computing resources


---

**Note**: This pipeline is designed for educational and research purposes. For clinical applications, additional validation and regulatory compliance may be required.
