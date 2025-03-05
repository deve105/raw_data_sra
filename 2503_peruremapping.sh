#!/bin/bash

set -euo pipefail #Stric mode

echo "Script for HLA-mapping by Daniel Enriquez-Vera"
echo "Version V1.2 2025-02-20"

# VARIABLES
maindir="/home/labatl/devprojects"
indexgenome="/home/labatl/devapps/2407_references/2405project_hg38/2405_hg38htlv.fa"
project_directory="/home/labatl/devprojects/Peru_IRID/HLA-LA"
echo "The base working directory is ${maindir}"

# Generate a list text of all fastq (IT IS NECESSARY TO EXECUTE IT IN THE FOLDER WHERE THE FASTQ.GZ ARE)

for file in *.fastq.gz; do
    echo "$file" | sed 's/R[0-9]_001.fastq.gz$//'
done | uniq > "${maindir}/Peru_IRID/Peru_IRID_initial.txt"

echo "Initial list of renamed files in ${maindir}/Peru_IRID/Peru_IRIDinitial.txt"

while IFS= read -r sra; do
    if [ ! -f "${sra}R1_001.fastq.gz" ] || [ ! -f "${sra}R3_001.fastq.gz" ]; then
        echo "Error: Missing FASTQ files for ${sra}. Expected ${sra}R1_001.fastq.gz and ${sra}R3_001.fastq.gz."
        exit 1
    fi
    newname=$(echo "${sra}" | sed -E 's/^.*Nakahata_//; s/_S[0-9].*$//')
        # copy and rename the fastq1 and fastq3
        echo "Copying and renaming ${sra}R1_001.fastq.gz to ${newname}_1.fq.gz" 
        rsync -av "${sra}R1_001.fastq.gz" "${maindir}/Peru_IRID/fastq/${newname}_1.fq.gz"
        echo "Copying and renaming ${sra}R3_001.fastq.gz to ${newname}_2.fq.gz" 
        rsync -av "${sra}R3_001.fastq.gz" "${maindir}/Peru_IRID/fastq/${newname}_2.fq.gz"
        echo "${newname}" >> "${maindir}/Peru_IRID/Peru_IRID.txt"
        # quality control with fastp
        echo "Quality control for ${newname}"
        fastp -i "${maindir}/Peru_IRID/fastq/${newname}_1.fq.gz" \
		    -I "${maindir}/Peru_IRID/fastq/${newname}_2.fq.gz" \
            -3 \
            -o "${maindir}/Peru_IRID/fastq/${newname}_postqc_1.fq.gz" \
            -O "${maindir}/Peru_IRID/fastq/${newname}_postqc_2.fq.gz" \
			-j "${maindir}/Peru_IRID/reports/${newname}_fastp.json" \
            -h "${maindir}/Peru_IRID/reports/${newname}_fastp.html" \
            -q 30 \
            -u 40 \
            -n 5 \
            --detect_adapter_for_pe \
            --dont_eval_duplication \
            -w 16
		rm "${maindir}/Peru_IRID/fastq/${newname}_1.fq.gz"  "${maindir}/Peru_IRID/fastq/${newname}_2.fq.gz" 
        fastq1="${maindir}/Peru_IRID/fastq/${newname}_postqc_1.fq.gz"
        fastq2="${maindir}/Peru_IRID/fastq/${newname}_postqc_2.fq.gz"
        bamq="${maindir}/Peru_IRID/bam/${newname}"
        #MAPPING
        echo "BWA-MEM2 mapping for ${newname}}"
        bwa-mem2 mem -t 30 "${indexgenome}" "${fastq1}" "${fastq2}" | \
        samtools view -o "${bamq}.bam"
        #SORTING
        echo "Sorting BAM file"
        samtools sort -@ 30 -o "${bamq}_sorted.bam" "${bamq}.bam"
        #INDEXING
        echo "Indexing BAM file"
        samtools index "${bamq}_sorted.bam"
        #HLA Typing
        echo "HLA Typing"
        HLA-LA.pl --BAM "${bamq}_sorted.bam" \
        --graph PRG_MHC_GRCh38_withIMGT \
        --sampleID ${newname} \
        --maxThreads 30 \
        --workingDir "${project_directory}" \
        --samtools_T "${indexgenome}"      
        rm "${bamq}.bam" "${bamq}_sorted.bam"
done < "${maindir}/Peru_IRID/Peru_IRID_initial.txt"

echo "Running MultiQC on the rawdata folder"
multiqc "${maindir}/Peru_IRID/reports" -o "${maindir}/Peru_IRID" -n "multiqc_report_postqc"
echo "MultiQC report generated in "${maindir}/Peru_IRID_multiqc_report_postqc.html"

