# 水稻 Ribo-seq rRNA & tRNA 数据库

这是一个专为水稻 (*Oryza sativa*) Ribo-seq 分析设计的完整 rRNA 和 tRNA 去除数据库。相比标准数据库，它增加了叶绿体和线粒体的 rRNA 以及所有细胞器的 tRNA 序列，能显著降低背景噪音，提高有效数据利用率。

## 📊 数据库内容

该数据库包含以下序列，旨在从 Ribo-seq 数据中去除核糖体 RNA (rRNA) 和转运 RNA (tRNA) 污染：

| 来源 | rRNA | tRNA |
|------|------|------|
| **细胞核** | 18S, 28S, 5.8S, 5S | 242 个 (覆盖所有氨基酸) |
| **叶绿体** | 16S, 23S, 4.5S, 5S | 30 个 |
| **线粒体** | 18S, 26S, 5S | 22 个 |
| **总计** | **11 种** | **294 个** |

## 🚀 快速开始

### 1. 验证数据库完整性

运行以下脚本检查所有数据库文件是否完整：

```bash
chmod +x check_database_integrity.sh
./check_database_integrity.sh
```

### 2. 在 nf-core/riboseq 中使用

本数据库已预配置好清单文件 `rice_rrna_trna_database_complete.txt`，可直接用于 [nf-core/riboseq](https://nf-co.re/riboseq) 流程。

**⚠️ 重要提示**: 使用前请务必打开 `rice_rrna_trna_database_complete.txt`，将 `/home/user/riceRNAdb/...` 路径修改为您机器上的**绝对路径**。

**运行示例：**

```bash
nextflow run nf-core/riboseq \
  --input samplesheet.csv \
  --fasta reference/rice_genome.fa \
  --gtf reference/rice_annotation.gtf \
  --ribo_database_manifest rice_rrna_trna_database_complete.txt \
  --outdir results \
  -profile docker
```

### 3. 手动使用 (如 Bowtie2)

如果需要手动去除污染，可以合并所有序列并构建索引：

```bash
# 合并 rRNA 和 tRNA 序列
cat riceRNAdb/rice_*_rRNA.fasta riceRNAdb/rice_all_tRNA.fasta > rice_contaminants.fa

# 构建 Bowtie2 索引
bowtie2-build rice_contaminants.fa rice_contaminants_idx

# 比对去除
bowtie2 -x rice_contaminants_idx -U raw_reads.fq.gz --un cleaned_reads.fq.gz -S contaminants.sam
```

## 🛠️ 重新构建数据库

如果您需要重新生成数据库文件（例如为了复现或更新版本），请按照以下顺序运行脚本：

1.  **准备 rRNA 数据库**
    ```bash
    bash prepare_rice_rrna.sh
    ```
    *   下载水稻叶绿体和线粒体基因组 (`.gb`)
    *   提取 rRNA 序列到 `riceRNAdb/`

2.  **准备 tRNA 数据库**
    ```bash
    bash add_rice_trna.sh
    ```
    *   下载并提取细胞核、叶绿体、线粒体 tRNA
    *   合并生成 `rice_all_tRNA.fasta`
    *   **注意**: 此脚本会尝试更新 `rice_rrna_trna_database_complete.txt`，运行后请检查路径是否正确。

## 📂 文件说明

*   **数据目录 (`riceRNAdb/`)**:
    *   `rice_chloroplast_rRNA.fasta`: 叶绿体 rRNA 序列
    *   `rice_mitochondrial_rRNA.fasta`: 线粒体 rRNA 序列
    *   `rice_all_tRNA.fasta`: 所有 tRNA 合并序列 (**推荐使用**)
    *   `rice_nuclear_tRNA.fa`: 仅细胞核 tRNA
    *   `rice_chloroplast_tRNA.fa`: 仅叶绿体 tRNA
    *   `rice_mitochondrial_tRNA.fa`: 仅线粒体 tRNA
    *   `*.gb`: GenBank 源文件 (用于提取序列)

*   **配置文件**:
    *   `rice_rrna_trna_database_complete.txt`: **核心配置文件**。包含所有 rRNA 和 tRNA 的路径清单。

*   **工具脚本**:
    *   `check_database_integrity.sh`: 验证文件完整性
    *   `prepare_rice_rrna.sh`: 构建 rRNA 数据库
    *   `add_rice_trna.sh`: 构建 tRNA 数据库

## 📚 数据来源

*   **rRNA**: SILVA (细胞核), NCBI GenBank (细胞器)
*   **tRNA**: GtRNAdb, Ensembl Plants
