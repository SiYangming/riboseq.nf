# RiboCode 模块集成说明

## 1. 概述
本流程已集成 RiboCode 工具，用于基于 Ribo-seq 数据进行 ORF (Open Reading Frame) 预测。RiboCode 模块并行于 RiboWaltz 运行，位于比对步骤（STAR/Salmon）之后。

## 2. 目录结构变更
为了符合 nf-core 最佳实践，RiboCode 子工作流已重新组织：
- **旧位置**: `subworkflows/local/ribocode.nf`
- **新位置**: `subworkflows/local/ribocode/main.nf`

此变更使得子工作流结构与其他本地子工作流（如 `prepare_genome`）保持一致。

## 3. 流程逻辑与数据流

RiboCode 子工作流 (`RIBOCODE`) 包含四个按顺序执行的步骤：

1.  **GTF Update (`RIBOCODE_GTFUPDATE`)**
    *   **输入**: 基因组注释文件 (GTF)
    *   **功能**: 转换和更新 GTF 文件格式以适配 RiboCode。
    *   **输出**: 更新后的 GTF 文件。

2.  **Prepare (`RIBOCODE_PREPARE`)**
    *   **输入**: 基因组序列 (FASTA), 更新后的 GTF
    *   **功能**: 提取转录本序列并准备注释数据库。
    *   **输出**: RiboCode 注释文件目录。

3.  **Metaplots (`RIBOCODE_METAPLOTS`)**
    *   **输入**: Ribo-seq 比对文件 (BAM), 注释文件
    *   **功能**: 生成元基因图 (metaplots) 并计算 P-site 偏移量。
    *   **输出**: P-site 配置文件 (`config.txt`), PDF 报告。

4.  **RiboCode (`RIBOCODE_RIBOCODE`)**
    *   **输入**: Ribo-seq 比对文件 (BAM), 注释文件, P-site 配置文件
    *   **功能**: 执行主 ORF 预测算法。
    *   **输出**: 预测的 ORF 列表 (`final_result.txt`), 简化的 ORF 列表 (`collapsed.txt`), 结果 PDF。

### 主流程集成点
在 `workflows/riboseq/main.nf` 中：
- 引入位置：`include { RIBOCODE } from '../../subworkflows/local/ribocode/main'`
- 调用位置：在 `RIBOWALTZ` 模块附近，`QUANTIFY_STAR_SALMON` 之前。
- 条件执行：由 `params.skip_ribocode` (默认 false) 控制。

## 4. 参数说明
- `--skip_ribocode`: 跳过 RiboCode 分析（默认：false）。
- `--extra_ribocode_args`: 传递给 RiboCode 主程序的额外参数。

## 5. 输出文件
结果将保存在 `results/ribocode/` 目录下：
- `prepare/`: 中间注释文件 (默认不发布，除非调试)。
- `metaplots/`: 元基因图 PDF 和 P-site 配置。
- `ribocode/`: 最终 ORF 预测结果表格和 PDF 报告。

## 6. 验证状态
- **配置检查**: 已通过。
- **流程构建**: 已通过。
- **模块调用**: 已验证 `RIBOCODE_GTFUPDATE` 能够被流程正确调度执行。
- **版本报告**: 已修复 `versions.yml` 生成方式，兼容 nf-core 流程版本汇总机制。
- **注意**: 测试运行时因网络原因无法拉取 `community.wave.seqera.io` 的 Docker 镜像，建议在网络畅通的环境下运行，或配置本地 Docker 镜像。
