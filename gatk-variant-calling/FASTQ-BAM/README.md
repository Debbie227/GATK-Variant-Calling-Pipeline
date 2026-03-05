## Part 2 FASTQ -> BAM

### FASTQC and read quality

```bash
pixi run fastqc data/test_1.fastq.gz data/test_2.fastq.gz
```

This creates fastqc.html and fastqc.zip files for each fastq file

Open the html file in a browser or create an html server to open the file.

In codespaces a new terminal and enter
```python
python3 -m http.server 8000
```
Go to the ports tab and follow the link for the forwarded address

Check the results of the FASTQC to find problems with your data. A full walkthrough of reading FASTQC results can be found here [Michigan State FASTQC Tutorial](https://rtsf.natsci.msu.edu/genomics/technical-documents/fastqc-tutorial-and-faq.aspx)

You will see that this test data fails several quality checks for FASTQC

### Trimming reads

```bash

```