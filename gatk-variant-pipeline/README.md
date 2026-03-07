```bash
# Create directory and begin pixi environment
mkdir gatk-variant-calling && cd $_

curl -fsSL https://pixi.sh/install.sh | bash
source ~/.bashrc

pixi install
```

```bash
# Create file tree
mkdir -p data/raw \
        data/trimmed \
        reference \
        results
```

```bash
# download small subset of data from SRA
cd data/raw/

pixi run fasterq-dump SRR37153337 \
  --split-files \
  -X 50000

# Error Failed to call external services.
# Conda may not have the latest version of SRA toolkit?

docker build -t sra-download .

# Same error

pixi run prefetch SRR37153337 \
    --max-size 41G

# Too big for codespaces to deal with...

```

