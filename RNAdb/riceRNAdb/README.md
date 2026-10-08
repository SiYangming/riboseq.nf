# 水稻 Ribo-seq rRNA & tRNA 数据库与预处理指南

这是一个专为水稻 (*Oryza sativa*) Ribo-seq 分析设计的完整 rRNA 和 tRNA 去除数据库。相比标准数据库，它增加了叶绿体和线粒体的 rRNA 以及所有细胞器的 tRNA 序列，能显著降低背景噪音，提高有效数据利用率。

本指南还详细说明了 Ribo-seq 预处理中 SortMeRNA 和 BBSplit 工具的区别与使用场景。

## 📊 数据库内容

该数据库包含以下序列，旨在从 Ribo-seq 数据中去除核糖体 RNA (rRNA) 和转运 RNA (tRNA) 污染：

| 来源 | rRNA | tRNA |
|------|------|------|
| **细胞核** | 18S, 28S, 5.8S, 5S | 242 个 (覆盖所有氨基酸) |
| **叶绿体** | 16S, 23S, 4.5S, 5S | 30 个 |
| **线粒体** | 18S, 26S, 5S | 22 个 |
| **总计** | **11 种** | **294 个** |

---

## ⚙️ 配置文件说明

为了保持配置文件的简洁，实际的配置文件中不包含任何注释。以下是对配置文件的详细说明：

### 1. `rice_rrna_trna_database_complete.txt`
这是用于 **SortMeRNA** 的清单文件，指定了需要过滤的 rRNA 和 tRNA 数据库路径。

包含的内容及其必要性：
- **真核生物核 rRNA** (`rfam-5.8s`, `rfam-5s`, `silva-euk-18s`, `silva-euk-28s`)：**必需**。这是主要的 rRNA 污染源。
- **水稻叶绿体 rRNA** (`rice_chloroplast_rRNA.fasta`)：**关键必需**。水稻特有，叶绿体中含有大量的 16S/23S 等 rRNA，常规数据库无法完全去除。
- **水稻线粒体 rRNA** (`rice_mitochondrial_rRNA.fasta`)：**关键必需**。水稻特有，需要专门去除。
- **水稻所有 tRNA** (`rice_all_tRNA.fasta`)：**强烈推荐**。tRNA 长度 (~70-90 nt) 经核酸酶消化后会产生与 footprint 相似的 28-32 nt 片段，不去除会导致假阳性翻译信号。
- **细菌 rRNA** (`silva-bac-16s`, `silva-bac-23s`)：**可选**。主要用于防止环境污染（例如田间采样）。如果是严格的实验室纯培养样本，可以在配置文件中删除这两行以提升速度。
- **古菌 rRNA**：**不推荐**。水稻样本极少有古菌污染，因此未包含在最终配置中。

### 2. `bbsplit_refs_for_rice.txt`
这是用于 **BBSplit** 的参考基因组列表，格式必须为 `物种标识符,完整基因组FASTA绝对路径`。
**注意：纯水稻样本不需要使用此文件！**（详见下方 BBSplit 说明）。该文件仅提供了一个格式示例（如稻瘟病菌和大肠杆菌），在实际使用 BBSplit 时，请将路径替换为您本地实际的基因组文件路径。

---

## 🔬 SortMeRNA vs BBSplit：深度解析与使用场景

在 Ribo-seq 分析中，这两个工具经常被混淆，但它们的作用和输入数据完全不同。

### 核心区别总结

| 对比项 | SortMeRNA | BBSplit |
|--------|-----------|---------|
| **功能** | 去除 rRNA/tRNA 污染 | 分离不同物种的 reads |
| **输入数据库** | rRNA/tRNA 序列集合（小，几 MB） | 完整基因组（大，数百 MB - 数 GB） |
| **处理对象** | 核糖体 RNA、转运 RNA | 整个基因组的所有序列 |
| **纯水稻样本必要性** | ✅ **必需**（所有样本） | ❌ **不需要**（跳过） |
| **是否改变 reads** | ❌ 不改变，仅过滤 | ❌ 不改变，仅分类 |

### 1. 为什么 SortMeRNA (rRNA 去除) 是必需的？

即使使用了 Ribo-Zero 等试剂盒，Ribo-seq 样本中仍会有大量 rRNA 残留（因为核酸酶消化会产生难以用常规方法去除的 28-30 nt rRNA 片段）。
如果不去除 rRNA：
- 浪费测序成本（rRNA reads 可能占 60-95%）。
- 严重干扰 P-site 位置分析、翻译效率计算和 ORF 预测。

**注意：叶绿体/线粒体 rRNA 需要去除，但它们的 mRNA 需要保留！**
这也是为什么我们不能用整个叶绿体基因组去过滤，而只能用 SortMeRNA 去除特定的 rRNA 序列。叶绿体和线粒体的 mRNA 翻译（如光合作用基因）是重要的科学信息。

### 2. 为什么纯水稻样本不需要 BBSplit？

BBSplit 的作用是分离混合样本中不同物种的 reads。
对于纯水稻组织（叶、根、种子等）或细胞培养物，所有 reads（包括核、叶绿体、线粒体）都来自水稻。BBSplit 会把所有 reads 归类到水稻参考基因组，等同于没有过滤，白白浪费计算资源。

**常见误区**：认为 BBSplit 能去除叶绿体 reads。
**真相**：BBSplit 需要的是完整基因组。如果您用 BBSplit 过滤叶绿体，会把叶绿体中有价值的 mRNA footprints 也一并删掉！

### 3. 什么时候才需要启用 BBSplit？

仅在您的样本中**存在多个物种**时启用 BBSplit：
- **病原体感染**：例如水稻 + 稻瘟病菌（Magnaporthe oryzae）或水稻条纹病毒（RSV）。
- **根际微生物群落**：例如水稻根系 + 假单胞菌/芽孢杆菌。
- **转基因/异源表达**：例如带有农杆菌污染的水稻样本。

---

## 🚀 流程运行建议 (nf-core/riboseq)

### 场景 A：标准纯水稻样本（推荐配置）
不需要 BBSplit，只需使用 SortMeRNA。

```bash
nextflow run nf-core/riboseq \
  --input samplesheet.csv \
  --fasta reference/rice_genome.fa \
  --gtf reference/rice_annotation.gtf \
  --remove_ribo_rna true \
  --ribo_database_manifest RNAdb/rice_rrna_trna_database_complete.txt \
  --skip_bbsplit true \
  --outdir results
```

### 场景 B：水稻 + 病原菌/微生物混合样本
需要启用 BBSplit 分离物种，同时使用 SortMeRNA 去除 rRNA。

```bash
nextflow run nf-core/riboseq \
  --input samplesheet.csv \
  --fasta reference/rice_genome.fa \
  --gtf reference/rice_annotation.gtf \
  --remove_ribo_rna true \
  --ribo_database_manifest RNAdb/rice_rrna_trna_database_complete.txt \
  --skip_bbsplit false \
  --bbsplit_fasta_list RNAdb/riceRNAdb/bbsplit_refs_for_rice.txt \
  --save_bbsplit_reads \
  --outdir results
```

---

## 🛠️ 质控与数据库维护

### 运行后质控检查点
1. **SortMeRNA 日志** (`results/sortmerna/*.log`)：对于水稻叶片，期望保留 40-60% 的 reads（叶绿体 rRNA 丰度极高）。如果保留率过低，检查是否使用了错误的数据库（如误用了全基因组）。
2. **STAR 比对率** (`results/star_salmon/*Log.final.out`)：Uniquely mapped 期望 > 70%。

### 验证与重建数据库
- **验证完整性**：运行 `./check_database_integrity.sh`
- **重新构建**：
  1. `bash prepare_rice_rrna.sh` (提取细胞器 rRNA)
  2. `bash add_rice_trna.sh` (提取合并 tRNA)

## 📂 文件目录说明
- `riceRNAdb/`：存放所有特定的 rRNA/tRNA FASTA 序列文件。
- `rice_rrna_trna_database_complete.txt`：SortMeRNA 的输入清单。
- `bbsplit_refs_for_rice.txt`：BBSplit 的输入清单示例（仅限多物种样本使用）。
- `check_database_integrity.sh`, `prepare_rice_rrna.sh`, `add_rice_trna.sh`：数据库管理脚本。
