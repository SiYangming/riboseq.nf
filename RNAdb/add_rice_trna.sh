#!/bin/bash

# 添加水稻 tRNA 序列脚本
# 作者: Seqera AI
# 日期: 2026-01-26

set -e

echo "=========================================="
echo "水稻 tRNA 序列下载与整合"
echo "=========================================="

# 创建工作目录
mkdir -p riceRNAdb
cd riceRNAdb

# 1. 从 Ensembl Plants 下载水稻 tRNA
echo ""
echo "[1/5] 下载水稻 ncRNA 序列（包含 tRNA）..."

wget -q -O - \
  "https://ftp.ensemblgenomes.ebi.ac.uk/pub/plants/release-58/fasta/oryza_sativa/ncrna/Oryza_sativa.IRGSP-1.0.ncrna.fa.gz" \
  | gunzip > rice_all_ncrna.fa 2>/dev/null || echo "下载失败，尝试备用方案..."

# 提取 tRNA
if [ -f rice_all_ncrna.fa ] && [ -s rice_all_ncrna.fa ]; then
  echo "提取细胞核 tRNA..."
  grep -A 1 "tRNA" rice_all_ncrna.fa | grep -v "^--$" > rice_nuclear_tRNA.fa || touch rice_nuclear_tRNA.fa
  rm rice_all_ncrna.fa
else
  echo "使用备用方案：从 GtRNAdb 下载..."
  wget -q -O rice_nuclear_tRNA.fa \
    "http://gtrnadb.ucsc.edu/genomes/eukaryota/Osati39/osati39-tRNAs.fa" \
    2>/dev/null || touch rice_nuclear_tRNA.fa
fi

# 2. 从叶绿体基因组提取 tRNA
echo ""
echo "[2/5] 提取水稻叶绿体 tRNA..."

# 检查是否已有叶绿体基因组
if [ ! -f rice_chloroplast.gb ]; then
  echo "下载水稻叶绿体基因组..."
  wget -q -O rice_chloroplast.gb \
    "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=NC_001320.1&rettype=gb&retmode=text"
  sleep 1
fi

# 使用 Python 提取 tRNA
python3 << 'PYTHON_SCRIPT'
import re
import os

def extract_trna_from_genbank(gb_file, output_file, source="chloroplast"):
    """从 GenBank 文件提取 tRNA 序列"""
    if not os.path.exists(gb_file):
        print(f"警告: {gb_file} 不存在")
        open(output_file, 'w').close()
        return 0
    
    with open(gb_file, 'r') as f:
        content = f.read()
    
    # 获取完整序列
    origin_match = re.search(r'ORIGIN\s+(.*?)//', content, re.DOTALL)
    if not origin_match:
        print(f"警告: 无法在 {gb_file} 中找到序列")
        open(output_file, 'w').close()
        return 0
    
    sequence_lines = origin_match.group(1).strip().split('\n')
    sequence = ''
    for line in sequence_lines:
        # 移除行首的数字和空格
        seq_part = re.sub(r'^\s*\d+\s*', '', line)
        sequence += seq_part.replace(' ', '').upper()
    
    # 提取 tRNA 特征
    trna_pattern = re.compile(
        r'tRNA\s+(?:complement\()?(\d+)\.\.(\d+)\)?.*?/product="(.*?)"',
        re.DOTALL
    )
    
    trnas = []
    for match in trna_pattern.finditer(content):
        start = int(match.group(1)) - 1  # 0-based
        end = int(match.group(2))
        product = match.group(3).strip()
        
        trna_seq = sequence[start:end]
        
        # 检查是否是反向互补
        if 'complement' in match.group(0):
            complement = {'A': 'T', 'T': 'A', 'G': 'C', 'C': 'G', 'N': 'N'}
            trna_seq = ''.join(complement.get(b, 'N') for b in reversed(trna_seq))
        
        trnas.append((product, trna_seq))
    
    # 写入 FASTA 文件
    with open(output_file, 'w') as f:
        for i, (product, seq) in enumerate(trnas, 1):
            # 清理产品名称
            product = product.replace(' ', '_').replace('"', '')
            f.write(f">Oryza_sativa_{source}_{product}_tRNA_{i}\n")
            f.write(f"{seq}\n")
    
    print(f"✓ 从 {gb_file} 提取了 {len(trnas)} 个 tRNA 序列")
    return len(trnas)

# 提取叶绿体 tRNA
extract_trna_from_genbank('rice_chloroplast.gb', 'rice_chloroplast_tRNA.fa', 'chloroplast')
PYTHON_SCRIPT

# 3. 从线粒体基因组提取 tRNA
echo ""
echo "[3/5] 提取水稻线粒体 tRNA..."

# 检查是否已有线粒体基因组
if [ ! -f rice_mitochondrion.gb ]; then
  echo "下载水稻线粒体基因组..."
  wget -q -O rice_mitochondrion.gb \
    "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=NC_011033.1&rettype=gb&retmode=text"
  sleep 1
fi

# 提取线粒体 tRNA
python3 << 'PYTHON_SCRIPT'
import re
import os

def extract_trna_from_genbank(gb_file, output_file, source="mitochondrion"):
    """从 GenBank 文件提取 tRNA 序列"""
    if not os.path.exists(gb_file):
        print(f"警告: {gb_file} 不存在")
        open(output_file, 'w').close()
        return 0
    
    with open(gb_file, 'r') as f:
        content = f.read()
    
    # 获取完整序列
    origin_match = re.search(r'ORIGIN\s+(.*?)//', content, re.DOTALL)
    if not origin_match:
        print(f"警告: 无法在 {gb_file} 中找到序列")
        open(output_file, 'w').close()
        return 0
    
    sequence_lines = origin_match.group(1).strip().split('\n')
    sequence = ''
    for line in sequence_lines:
        seq_part = re.sub(r'^\s*\d+\s*', '', line)
        sequence += seq_part.replace(' ', '').upper()
    
    # 提取 tRNA 特征
    trna_pattern = re.compile(
        r'tRNA\s+(?:complement\()?(\d+)\.\.(\d+)\)?.*?/product="(.*?)"',
        re.DOTALL
    )
    
    trnas = []
    for match in trna_pattern.finditer(content):
        start = int(match.group(1)) - 1
        end = int(match.group(2))
        product = match.group(3).strip()
        
        trna_seq = sequence[start:end]
        
        if 'complement' in match.group(0):
            complement = {'A': 'T', 'T': 'A', 'G': 'C', 'C': 'G', 'N': 'N'}
            trna_seq = ''.join(complement.get(b, 'N') for b in reversed(trna_seq))
        
        trnas.append((product, trna_seq))
    
    # 写入文件
    with open(output_file, 'w') as f:
        for i, (product, seq) in enumerate(trnas, 1):
            product = product.replace(' ', '_').replace('"', '')
            f.write(f">Oryza_sativa_{source}_{product}_tRNA_{i}\n")
            f.write(f"{seq}\n")
    
    print(f"✓ 从 {gb_file} 提取了 {len(trnas)} 个 tRNA 序列")
    return len(trnas)

# 提取线粒体 tRNA
extract_trna_from_genbank('rice_mitochondrion.gb', 'rice_mitochondrial_tRNA.fa', 'mitochondrion')
PYTHON_SCRIPT

# 4. 合并所有 tRNA 序列
echo ""
echo "[4/5] 合并所有 tRNA 序列..."

cat rice_nuclear_tRNA.fa \
    rice_chloroplast_tRNA.fa \
    rice_mitochondrial_tRNA.fa \
    > rice_all_tRNA.fasta 2>/dev/null || touch rice_all_tRNA.fasta

# 统计
nuclear_count=$(grep -c "^>" rice_nuclear_tRNA.fa 2>/dev/null || echo "0")
chloro_count=$(grep -c "^>" rice_chloroplast_tRNA.fa 2>/dev/null || echo "0")
mito_count=$(grep -c "^>" rice_mitochondrial_tRNA.fa 2>/dev/null || echo "0")
total_count=$(grep -c "^>" rice_all_tRNA.fasta 2>/dev/null || echo "0")

echo ""
echo "tRNA 序列统计:"
echo "  - 细胞核 tRNA: $nuclear_count 个"
echo "  - 叶绿体 tRNA: $chloro_count 个"
echo "  - 线粒体 tRNA: $mito_count 个"
echo "  - 总计: $total_count 个"

# 获取文件大小
if [ -f rice_all_tRNA.fasta ]; then
  trna_size=$(du -h rice_all_tRNA.fasta | cut -f1)
  echo "  - 文件大小: $trna_size"
fi

# 5. 更新数据库配置文件
echo ""
echo "[5/5] 更新 rRNA+tRNA 数据库配置..."

cd ..

cat > rice_rrna_trna_database_complete.txt << 'CONFIG'
# 水稻完整 rRNA + tRNA 数据库配置
# 用于 Ribo-seq 分析中去除 rRNA 和 tRNA 污染

# ============================================
# rRNA 数据库
# ============================================

# 真核生物核 rRNA
https://raw.githubusercontent.com/biocore/sortmerna/v4.3.4/data/rRNA_databases/silva-euk-18s-id95.fasta
https://raw.githubusercontent.com/biocore/sortmerna/v4.3.4/data/rRNA_databases/silva-euk-28s-id98.fasta
https://raw.githubusercontent.com/biocore/sortmerna/v4.3.4/data/rRNA_databases/rfam-5.8s-database-id98.fasta
https://raw.githubusercontent.com/biocore/sortmerna/v4.3.4/data/rRNA_databases/rfam-5s-database-id98.fasta

# 水稻叶绿体 rRNA（本地文件）
/home/user/riceRNAdb/rice_chloroplast_rRNA.fasta

# 水稻线粒体 rRNA（本地文件）
/home/user/riceRNAdb/rice_mitochondrial_rRNA.fasta

# ============================================
# tRNA 数据库
# ============================================

# 水稻所有 tRNA（细胞核 + 叶绿体 + 线粒体）
/home/user/riceRNAdb/rice_all_tRNA.fasta
CONFIG

echo ""
echo "=========================================="
echo "✓ 完成！"
echo "=========================================="
echo ""
echo "生成的文件:"
ls -lh riceRNAdb/*.fasta 2>/dev/null | tail -5
echo ""
echo "配置文件: rice_rrna_trna_database_complete.txt"
echo ""

