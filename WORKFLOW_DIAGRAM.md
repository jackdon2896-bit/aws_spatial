# 🔀 Pipeline Workflow Diagram

## Dual-Path Architecture (H5 vs SRA)

```
┌─────────────────────────────────────────────────────────────────────┐
│                     PIPELINE ENTRY POINT                            │
│                     nextflow run main.nf                            │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │ Parameter Validation  │
                    │  - tiff required      │
                    │  - h5 OR sra_ids      │
                    └───────────────────────┘
                                │
                    ┌───────────┴────────────┐
                    │                        │
        ┌───────────▼──────────┐  ┌─────────▼──────────┐
        │   params.sra_ids?    │  │    params.h5?      │
        │       (NEW!)         │  │    (ORIGINAL)      │
        └──────────────────────┘  └────────────────────┘
                    │                        │
                    │                        │
    ┌───────────────▼─────────────┐          │
    │   SRA WORKFLOW (PARALLEL)   │          │
    └─────────────────────────────┘          │
                    │                        │
        ┌───────────▼───────────┐            │
        │  SRA_DOWNLOAD         │            │
        │  - Download FASTQ     │            │
        │  - Per SRA ID         │            │
        └───────────────────────┘            │
                    │                        │
        ┌───────────▼───────────┐            │
        │  Group FASTQ files    │            │
        │  - By SRA ID          │            │
        │  - Create meta tuple  │            │
        └───────────────────────┘            │
                    │                        │
        ┌───────────▼───────────┐            │
        │  FASTQ_TO_H5AD        │            │
        │  - Convert to AnnData │            │
        └───────────────────────┘            │
                    │                        │
                    └──────────┬─────────────┘
                               │
                   ┌───────────▼───────────┐
                   │   H5_TO_H5AD          │
                   │   - Convert H5 to     │
                   │     AnnData format    │
                   └───────────────────────┘
                               │
                               │  h5ad_ch (AnnData object)
                               │
    ┌──────────────────────────┴──────────────────────────┐
    │                                                      │
    │            SPATIAL ANALYSIS PIPELINE                 │
    │           (Common for both workflows)                │
    │                                                      │
    └──────────────────────────────────────────────────────┘
                               │
                ┌──────────────▼──────────────┐
                │    IMAGE PREPROCESSING      │
                └─────────────────────────────┘
                               │
        ┌──────────────────────▼──────────────────────┐
        │  PREPROCESS_IMAGE                           │
        │  Input:  TIFF image                         │
        │  Output: filled.tif                         │
        │  Tool:   bin/preprocess_image.py            │
        └─────────────────────────────────────────────┘
                               │
        ┌──────────────────────▼──────────────────────┐
        │  CELLPOSE_SEGMENT                           │
        │  Input:  filled.tif                         │
        │  Output: mask.tif                           │
        │  Tool:   bin/segment_cellpose.py (Cellpose) │
        └─────────────────────────────────────────────┘
                               │
        ┌──────────────────────▼──────────────────────┐
        │  AI_ROI_CROP                                │
        │  Input:  filled.tif, mask.tif               │
        │  Output: cropped.tif, cropped_mask.tif      │
        │  Tool:   bin/ai_roi_crop.py                 │
        └─────────────────────────────────────────────┘
                               │
                ┌──────────────▼──────────────┐
                │  SPATIAL TRANSCRIPTOMICS    │
                │  ANALYSIS (scanpy/squidpy)  │
                └─────────────────────────────┘
                               │
        ┌──────────────────────▼──────────────────────┐
        │  QC                                         │
        │  Input:  cropped_mask.tif, h5ad             │
        │  Output: qc.h5ad                            │
        │  Tool:   bin/qc.py (scanpy QC metrics)      │
        └─────────────────────────────────────────────┘
                               │
        ┌──────────────────────▼──────────────────────┐
        │  MAD_FILTER                                 │
        │  Input:  qc.h5ad                            │
        │  Output: filtered.h5ad                      │
        │  Tool:   bin/mad_filter.py (MAD filtering)  │
        └─────────────────────────────────────────────┘
                               │
        ┌──────────────────────▼──────────────────────┐
        │  DIMENSIONALITY_REDUCTION                   │
        │  Input:  filtered.h5ad                      │
        │  Output: reduced.h5ad                       │
        │  Tool:   bin/dim_reduction.py (PCA/UMAP)    │
        └─────────────────────────────────────────────┘
                               │
        ┌──────────────────────▼──────────────────────┐
        │  CLUSTERING                                 │
        │  Input:  reduced.h5ad                       │
        │  Output: clustered.h5ad                     │
        │  Tool:   bin/cluster.py (Leiden/Louvain)    │
        └─────────────────────────────────────────────┘
                               │
        ┌──────────────────────▼──────────────────────┐
        │  ANNOTATION                                 │
        │  Input:  clustered.h5ad                     │
        │  Output: annotated.h5ad                     │
        │  Tool:   bin/annotate_celltypist.py         │
        └─────────────────────────────────────────────┘
                               │
        ┌──────────────────────▼──────────────────────┐
        │  SPATIAL_REFINE                             │
        │  Input:  annotated.h5ad                     │
        │  Output: refined.h5ad                       │
        │  Tool:   bin/spatial_refine.py (squidpy)    │
        └─────────────────────────────────────────────┘
                               │
        ┌──────────────────────▼──────────────────────┐
        │  INTEGRATE                                  │
        │  Input:  refined.h5ad                       │
        │  Output: integrated.h5ad                    │
        │  Tool:   bin/spatial_integrate.py           │
        └─────────────────────────────────────────────┘
                               │
        ┌──────────────────────▼──────────────────────┐
        │  REPORT                                     │
        │  Input:  integrated.h5ad                    │
        │  Output: report.md                          │
        │  Tool:   bin/report.py                      │
        └─────────────────────────────────────────────┘
                               │
                               ▼
                    ┌────────────────────┐
                    │  PIPELINE COMPLETE │
                    │  Results published │
                    │  to: params.outdir │
                    └────────────────────┘
```

---

## Channel Flow Diagram

```
DUAL INPUT PATHS:

PATH 1: SRA Download
═══════════════════════════════════════════════════════════════
params.sra_ids (String: "SRR123,SRR456")
    │
    ├─── .tokenize(',')
    │
    ▼
sra_ids_ch: [ "SRR123", "SRR456" ]
    │
    ├─── SRA_DOWNLOAD
    │
    ▼
sra_downloads.fastq: [ SRR123_1.fq, SRR123_2.fq, SRR456_1.fq, SRR456_2.fq ]
    │
    ├─── .map { extract SRA ID }
    │
    ▼
[ tuple("SRR123", SRR123_1.fq), 
  tuple("SRR123", SRR123_2.fq),
  tuple("SRR456", SRR456_1.fq),
  tuple("SRR456", SRR456_2.fq) ]
    │
    ├─── .groupTuple()
    │
    ▼
[ tuple("SRR123", [SRR123_1.fq, SRR123_2.fq]),
  tuple("SRR456", [SRR456_1.fq, SRR456_2.fq]) ]
    │
    ├─── .map { add meta }
    │
    ▼
fastq_grouped: [ tuple([id:"SRR123"], [SRR123_1.fq, SRR123_2.fq]),
                 tuple([id:"SRR456"], [SRR456_1.fq, SRR456_2.fq]) ]
    │
    ├─── FASTQ_TO_H5AD
    │
    ▼
h5ad_ch: [ SRR123.h5ad, SRR456.h5ad ]
═══════════════════════════════════════════════════════════════

PATH 2: H5 Direct
═══════════════════════════════════════════════════════════════
params.h5 (Path: "s3://bucket/matrix.h5")
    │
    ├─── Channel.fromPath()
    │
    ▼
h5_ch: [ matrix.h5 ]
    │
    ├─── H5_TO_H5AD
    │
    ▼
h5ad_ch: [ matrix.h5ad ]
═══════════════════════════════════════════════════════════════

MERGED PATH: Spatial Analysis
═══════════════════════════════════════════════════════════════
tiff_ch: [ image.tif ]
    │
    ├─── PREPROCESS_IMAGE
    │
    ▼
filled_ch: [ filled.tif ]
    │
    ├─── CELLPOSE_SEGMENT
    │
    ▼
mask_ch: [ mask.tif ]
    │
    ├─── AI_ROI_CROP (filled_ch, mask_ch)
    │
    ▼
roi_result.cropped: [ cropped.tif ]
roi_result.cropped_mask: [ cropped_mask.tif ]
    │
    ├─── QC (roi_result.cropped_mask, h5ad_ch)
    │
    ▼
qc_ch: [ qc.h5ad ]
    │
    ├─── MAD_FILTER
    │
    ▼
filtered_ch: [ filtered.h5ad ]
    │
    ├─── DIMENSIONALITY_REDUCTION
    │
    ▼
reduced_ch: [ reduced.h5ad ]
    │
    ├─── CLUSTERING
    │
    ▼
clustered_ch: [ clustered.h5ad ]
    │
    ├─── ANNOTATION
    │
    ▼
annotated_ch: [ annotated.h5ad ]
    │
    ├─── SPATIAL_REFINE
    │
    ▼
refined_ch: [ refined.h5ad ]
    │
    ├─── INTEGRATE
    │
    ▼
integrated_ch: [ integrated.h5ad ]
    │
    ├─── REPORT
    │
    ▼
report: [ report.md ]
═══════════════════════════════════════════════════════════════
```

---

## Process Dependency Graph

```
                    ┌──────────────────────┐
                    │   INPUT PARAMETERS   │
                    └──────────────────────┘
                             │
                ┌────────────┴────────────┐
                │                         │
        ┌───────▼────────┐       ┌────────▼───────┐
        │   tiff_ch      │       │  h5_ch OR      │
        │                │       │  sra_ids_ch    │
        └───────┬────────┘       └────────┬───────┘
                │                         │
                │              ┌──────────┴────────┐
                │              │                   │
                │    ┌─────────▼──────┐   ┌────────▼────────┐
                │    │ SRA_DOWNLOAD   │   │  H5_TO_H5AD     │
                │    │ (parallel per  │   │                 │
                │    │  SRA ID)       │   │                 │
                │    └────────┬───────┘   └────────┬────────┘
                │             │                    │
                │    ┌────────▼────────┐           │
                │    │ FASTQ_TO_H5AD   │           │
                │    │ (grouped FASTQ) │           │
                │    └────────┬────────┘           │
                │             │                    │
                │             └──────────┬─────────┘
                │                        │
                │                   h5ad_ch
                │                        │
    ┌───────────▼──────────┐             │
    │ PREPROCESS_IMAGE     │             │
    │                      │             │
    └───────────┬──────────┘             │
                │                        │
    ┌───────────▼──────────┐             │
    │ CELLPOSE_SEGMENT     │             │
    │                      │             │
    └───────────┬──────────┘             │
                │                        │
    ┌───────────▼──────────┐             │
    │ AI_ROI_CROP          │             │
    │                      │             │
    └───────────┬──────────┘             │
                │                        │
                └────────────┬───────────┘
                             │
                ┌────────────▼───────────┐
                │        QC              │
                └────────────┬───────────┘
                             │
                ┌────────────▼───────────┐
                │     MAD_FILTER         │
                └────────────┬───────────┘
                             │
                ┌────────────▼───────────┐
                │ DIMENSIONALITY_        │
                │ REDUCTION              │
                └────────────┬───────────┘
                             │
                ┌────────────▼───────────┐
                │    CLUSTERING          │
                └────────────┬───────────┘
                             │
                ┌────────────▼───────────┐
                │    ANNOTATION          │
                └────────────┬───────────┘
                             │
                ┌────────────▼───────────┐
                │  SPATIAL_REFINE        │
                └────────────┬───────────┘
                             │
                ┌────────────▼───────────┐
                │    INTEGRATE           │
                └────────────┬───────────┘
                             │
                ┌────────────▼───────────┐
                │      REPORT            │
                └────────────────────────┘
```

---

## Parallelization Strategy

```
PARALLEL EXECUTION (when using multiple SRA IDs):

Time →

─────────────────────────────────────────────────────────
|  SRA_DOWNLOAD("SRR123")  |  FASTQ_TO_H5AD("SRR123")  |
─────────────────────────────────────────────────────────
|  SRA_DOWNLOAD("SRR456")  |  FASTQ_TO_H5AD("SRR456")  |
─────────────────────────────────────────────────────────
|  SRA_DOWNLOAD("SRR789")  |  FASTQ_TO_H5AD("SRR789")  |
─────────────────────────────────────────────────────────
                              ↓
                       All H5AD merged
                              ↓
                         QC (sequential)
                              ↓
                       MAD_FILTER
                              ↓
                            ...
```

**Key Benefits:**
- SRA downloads run in parallel (one process per SRA ID)
- FASTQ to H5AD conversion runs in parallel
- Image processing runs independently
- Spatial analysis is sequential (requires merged data)

---

## Data Flow Summary

| Stage | Input Format | Output Format | Key Tool |
|-------|-------------|---------------|----------|
| SRA Download | SRA ID | FASTQ | sra-tools |
| FASTQ→H5AD | FASTQ | AnnData (.h5ad) | scanpy |
| H5→H5AD | H5 matrix | AnnData (.h5ad) | scanpy |
| Preprocessing | TIFF | TIFF (filled) | Custom |
| Segmentation | TIFF | TIFF (mask) | Cellpose |
| ROI Cropping | TIFF + mask | Cropped TIFF/mask | Custom |
| QC | mask + h5ad | h5ad + metrics | scanpy |
| Filtering | h5ad | h5ad (filtered) | scanpy |
| Reduction | h5ad | h5ad (PCA/UMAP) | scanpy |
| Clustering | h5ad | h5ad (clusters) | scanpy |
| Annotation | h5ad | h5ad (types) | CellTypist |
| Refinement | h5ad | h5ad (refined) | squidpy |
| Integration | h5ad | h5ad (final) | Custom |
| Reporting | h5ad | Markdown | Custom |

---

## Resource Usage Pattern

```
MEMORY USAGE OVER TIME:

High ┤                        ╭────╮
     │                    ╭───╯    ╰───╮
     │                ╭───╯            ╰───╮
Med  │            ╭───╯                    ╰───╮
     │        ╭───╯                            ╰───╮
     │    ╭───╯                                    ╰───
Low  ├────╯
     └─────────────────────────────────────────────────→ Time
     │    │   │    │     │    │    │    │    │    │
     PRE SEG ROI  QC  FILT RED CLUS ANN REF  INT REP

CPU USAGE:

High ┤ ╭╮  ╭╮     ╭╮         ╭╮
     │ ││  ││     ││         ││
     │ ││  ││     ││         ││
Med  │ ││  ││     ││     ╭╮  ││     ╭╮
     │ ││  ││     ││     ││  ││     ││
     │ ││  ││     ││     ││  ││     ││      ╭╮
Low  ├─╯╰──╯╰─────╯╰─────╯╰──╯╰─────╯╰──────╯╰────
     └─────────────────────────────────────────────→ Time
     │   │   │    │     │    │    │    │    │    │
     PRE SEG ROI  QC  FILT RED CLUS ANN REF  INT REP
```

**Resource-intensive stages:**
1. CELLPOSE_SEGMENT - High CPU (deep learning)
2. ANNOTATION - High memory (large models)
3. SPATIAL_REFINE - High memory + CPU (spatial analysis)
4. INTEGRATE - High memory (full dataset)

---

## Error Recovery Points

```
RESUME CAPABILITY:

Nextflow tracks completed tasks and can resume from failures:

┌──────────────┐
│ Task 1: PREP │ ✅ Completed (cached)
└──────────────┘
        │
┌──────────────┐
│ Task 2: SEG  │ ✅ Completed (cached)
└──────────────┘
        │
┌──────────────┐
│ Task 3: ROI  │ ❌ Failed
└──────────────┘
        │
     [Resume]
        │
┌──────────────┐
│ Task 3: ROI  │ ← Starts here (doesn't re-run 1, 2)
└──────────────┘
        │
     [Continue]
```

**To resume failed runs:**
```bash
nextflow run main.nf \
  --tiff s3://bucket/image.tif \
  --h5 s3://bucket/matrix.h5 \
  -resume
```

---

**Pipeline Complexity:**
- **Total processes:** 14
- **Parallel branches:** 2 (SRA vs H5)
- **Sequential stages:** 11 (after merge)
- **Maximum parallelism:** N (where N = number of SRA IDs)
- **Total runtime:** ~30min - 4hrs (depends on data size)
