#!/bin/bash

# 数据库完整性检查脚本
# 作者: Seqera AI
# 日期: 2026-01-26

echo "=========================================="
echo "水稻 Ribo-seq 数据库完整性检查"
echo "=========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查计数器
errors=0
warnings=0

# 函数：检查文件是否存在
check_file() {
    local file=$1
    local min_size=$2
    local description=$3
    
    if [ ! -f "$file" ]; then
        echo -e "${RED}✗ 错误: $description 不存在${NC}"
        echo "  预期文件: $file"
        ((errors++))
        return 1
    fi
    
    local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    
    if [ -z "$size" ]; then
        echo -e "${YELLOW}⚠ 警告: 无法获取 $description 的大小${NC}"
        ((warnings++))
        return 1
    fi
    
    if [ "$size" -lt "$min_size" ]; then
        echo -e "${YELLOW}⚠ 警告: $description 文件过小（${size} bytes < ${min_size} bytes）${NC}"
        echo "  文件: $file"
        ((warnings++))
        return 1
    fi
    
    echo -e "${GREEN}✓ $description: $(numfmt --to=iec $size 2>/dev/null || echo "${size} bytes")${NC}"
    return 0
}

# 函数：检查 FASTA 序列数量
check_fasta_count() {
    local file=$1
    local min_count=$2
    local description=$3
    
    if [ ! -f "$file" ]; then
        return 1
    fi
    
    local count=$(grep -c "^>" "$file" 2>/dev/null || echo "0")
    
    if [ "$count" -lt "$min_count" ]; then
        echo -e "${YELLOW}⚠ 警告: $description 序列数量少于预期（$count < $min_count）${NC}"
        ((warnings++))
    else
        echo -e "${GREEN}  包含 $count 条序列${NC}"
    fi
}

echo "=== 检查 rRNA 数据库 ==="
echo ""

check_file "riceRNAdb/rice_chloroplast_rRNA.fasta" 9000 "叶绿体 rRNA"
check_fasta_count "riceRNAdb/rice_chloroplast_rRNA.fasta" 4 "叶绿体 rRNA"

echo ""
check_file "riceRNAdb/rice_mitochondrial_rRNA.fasta" 5000 "线粒体 rRNA"
check_fasta_count "riceRNAdb/rice_mitochondrial_rRNA.fasta" 3 "线粒体 rRNA"

echo ""
echo "=== 检查 tRNA 数据库 ==="
echo ""

check_file "riceRNAdb/rice_nuclear_tRNA.fa" 10000 "细胞核 tRNA"
check_fasta_count "riceRNAdb/rice_nuclear_tRNA.fa" 200 "细胞核 tRNA"

echo ""
check_file "riceRNAdb/rice_chloroplast_tRNA.fa" 2000 "叶绿体 tRNA"
check_fasta_count "riceRNAdb/rice_chloroplast_tRNA.fa" 25 "叶绿体 tRNA"

echo ""
check_file "riceRNAdb/rice_mitochondrial_tRNA.fa" 1500 "线粒体 tRNA"
check_fasta_count "riceRNAdb/rice_mitochondrial_tRNA.fa" 20 "线粒体 tRNA"

echo ""
check_file "riceRNAdb/rice_all_tRNA.fasta" 60000 "合并 tRNA（总计）"
check_fasta_count "riceRNAdb/rice_all_tRNA.fasta" 250 "合并 tRNA"

echo ""
echo "=== 检查配置文件 ==="
echo ""

check_file "rice_rrna_trna_database_complete.txt" 500 "数据库配置文件"

# 检查配置文件内容
if [ -f "rice_rrna_trna_database_complete.txt" ]; then
    local_files=$(grep "^/home/user" rice_rrna_trna_database_complete.txt | wc -l)
    remote_files=$(grep "^https://" rice_rrna_trna_database_complete.txt | wc -l)
    
    echo -e "${GREEN}  包含 $remote_files 个远程数据库链接${NC}"
    echo -e "${GREEN}  包含 $local_files 个本地数据库文件${NC}"
    
    if [ "$local_files" -ne 3 ]; then
        echo -e "${YELLOW}⚠ 警告: 预期 3 个本地文件（2 个 rRNA + 1 个 tRNA），实际 $local_files 个${NC}"
        ((warnings++))
    fi
fi

echo ""
echo "=== 检查 GenBank 源文件（可选）==="
echo ""

if [ -f "riceRNAdb/rice_chloroplast.gb" ]; then
    check_file "riceRNAdb/rice_chloroplast.gb" 100000 "叶绿体基因组 (GenBank)"
else
    echo -e "${YELLOW}⚠ 叶绿体 GenBank 文件未保留（不影响使用）${NC}"
fi

if [ -f "riceRNAdb/rice_mitochondrion.gb" ]; then
    check_file "riceRNAdb/rice_mitochondrion.gb" 400000 "线粒体基因组 (GenBank)"
else
    echo -e "${YELLOW}⚠ 线粒体 GenBank 文件未保留（不影响使用）${NC}"
fi

echo ""
echo "=== 序列完整性检查 ==="
echo ""

# 检查是否有空序列
echo "检查空序列..."
empty_sequences=0
for fasta_file in riceRNAdb/*.fasta riceRNAdb/*.fa; do
    if [ -f "$fasta_file" ]; then
        # 检查是否有连续的 > 符号（表示空序列）
        empty=$(grep -Pzo '>\N+\n>' "$fasta_file" 2>/dev/null | grep -c "^>" || echo "0")
        if [ "$empty" -gt 0 ]; then
            echo -e "${RED}✗ 发现 $empty 个空序列: $fasta_file${NC}"
            ((errors++))
            ((empty_sequences+=empty))
        fi
    fi
done

if [ "$empty_sequences" -eq 0 ]; then
    echo -e "${GREEN}✓ 未发现空序列${NC}"
fi

# 检查序列命名
echo ""
echo "检查序列命名规范..."
naming_issues=0
for fasta_file in riceRNAdb/*.fasta riceRNAdb/*.fa; do
    if [ -f "$fasta_file" ]; then
        # 检查序列名是否包含空格或特殊字符
        bad_names=$(grep "^>" "$fasta_file" | grep -E "[\s;,]" | wc -l)
        if [ "$bad_names" -gt 0 ]; then
            echo -e "${YELLOW}⚠ 发现 $bad_names 个可能有问题的序列名: $fasta_file${NC}"
            ((warnings++))
            ((naming_issues++))
        fi
    fi
done

if [ "$naming_issues" -eq 0 ]; then
    echo -e "${GREEN}✓ 序列命名规范正常${NC}"
fi

echo ""
echo "=========================================="
echo "检查完成"
echo "=========================================="
echo ""

# 总结
if [ "$errors" -eq 0 ] && [ "$warnings" -eq 0 ]; then
    echo -e "${GREEN}✓✓✓ 所有检查通过！数据库完整且正确。${NC}"
    echo ""
    echo "您现在可以使用以下配置文件运行 Ribo-seq 流程："
    echo "  rice_rrna_trna_database_complete.txt"
    echo ""
    exit 0
elif [ "$errors" -eq 0 ]; then
    echo -e "${YELLOW}⚠ 发现 $warnings 个警告，但无严重错误${NC}"
    echo "数据库应该可以正常使用，但建议检查警告内容"
    echo ""
    exit 0
else
    echo -e "${RED}✗ 发现 $errors 个错误和 $warnings 个警告${NC}"
    echo "请修复错误后再使用数据库"
    echo ""
    echo "修复建议："
    echo "1. 重新运行准备脚本："
    echo "   bash prepare_rice_rrna.sh"
    echo "   bash add_rice_trna.sh"
    echo ""
    echo "2. 检查文件路径是否正确"
    echo "3. 确保有足够的磁盘空间和网络连接"
    echo ""
    exit 1
fi
