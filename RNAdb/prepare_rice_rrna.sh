#!/bin/bash
# 准备水稻 rRNA 序列（包括叶绿体和线粒体）

set -e

echo "正在准备水稻 rRNA 数据库..."

# 创建输出目录
mkdir -p rice_rrna_db

# 1. 下载水稻叶绿体基因组（NCBI RefSeq）
echo "下载水稻叶绿体基因组..."
wget -O rice_rrna_db/rice_chloroplast.gb \
  "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=NC_001320.1&rettype=gb&retmode=text"

# 2. 下载水稻线粒体基因组
echo "下载水稻线粒体基因组..."
wget -O rice_rrna_db/rice_mitochondrion.gb \
  "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=NC_011033.1&rettype=gb&retmode=text"

# 3. 提取 rRNA 序列（使用 Python 或手动提取）
cat > rice_rrna_db/extract_rrna.py <<'EOF'
#!/usr/bin/env python3
from Bio import SeqIO
import sys

def extract_rrna(genbank_file, output_fasta, source_name):
    """从 GenBank 文件提取 rRNA 序列"""
    with open(output_fasta, 'w') as out:
        for record in SeqIO.parse(genbank_file, "genbank"):
            for feature in record.features:
                if feature.type == "rRNA":
                    # 获取 rRNA 序列
                    seq = feature.extract(record.seq)
                    # 获取产品名称
                    product = feature.qualifiers.get('product', ['unknown'])[0]
                    # 写入 FASTA
                    header = f">{source_name}_{product.replace(' ', '_')}"
                    out.write(f"{header}\n{seq}\n")
    print(f"提取完成: {output_fasta}")

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("用法: extract_rrna.py <genbank_file> <output_fasta> <source_name>")
        sys.exit(1)
    
    extract_rrna(sys.argv[1], sys.argv[2], sys.argv[3])
EOF

chmod +x rice_rrna_db/extract_rrna.py

# 检查是否安装了 BioPython
if python3 -c "import Bio" 2>/dev/null; then
    echo "提取叶绿体 rRNA..."
    python3 rice_rrna_db/extract_rrna.py \
        rice_rrna_db/rice_chloroplast.gb \
        rice_rrna_db/rice_chloroplast_rRNA.fasta \
        "Oryza_sativa_chloroplast"
    
    echo "提取线粒体 rRNA..."
    python3 rice_rrna_db/extract_rrna.py \
        rice_rrna_db/rice_mitochondrion.gb \
        rice_rrna_db/rice_mitochondrial_rRNA.fasta \
        "Oryza_sativa_mitochondrion"
else
    echo "警告: 未安装 BioPython，请手动提取 rRNA 序列"
    echo "或运行: pip install biopython"
fi

# 4. 创建最终的 rRNA 数据库配置文件
cat > rice_rrna_database_complete.txt <<EOF
# 水稻完整 rRNA 数据库配置

# 真核生物核 rRNA
https://raw.githubusercontent.com/biocore/sortmerna/v4.3.4/data/rRNA_databases/silva-euk-18s-id95.fasta
https://raw.githubusercontent.com/biocore/sortmerna/v4.3.4/data/rRNA_databases/silva-euk-28s-id98.fasta
https://raw.githubusercontent.com/biocore/sortmerna/v4.3.4/data/rRNA_databases/rfam-5.8s-database-id98.fasta
https://raw.githubusercontent.com/biocore/sortmerna/v4.3.4/data/rRNA_databases/rfam-5s-database-id98.fasta

# 水稻叶绿体 rRNA（本地文件）
$(pwd)/rice_rrna_db/rice_chloroplast_rRNA.fasta

# 水稻线粒体 rRNA（本地文件）
$(pwd)/rice_rrna_db/rice_mitochondrial_rRNA.fasta
EOF

echo ""
echo "✅ 准备完成！"
echo ""
echo "生成的文件："
ls -lh rice_rrna_db/
echo ""
echo "rRNA 数据库配置文件: rice_rrna_database_complete.txt"
echo ""
echo "使用方法："
echo "nextflow run nf-core/riboseq \\"
echo "  --input samplesheet.csv \\"
echo "  --ribo_database_manifest rice_rrna_database_complete.txt \\"
echo "  --genome rice \\"
echo "  --outdir results"
