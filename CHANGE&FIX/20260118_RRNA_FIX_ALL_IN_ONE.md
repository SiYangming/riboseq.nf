# 🧬 nf-core/riboseq rRNA 数据库错误一站式修复文档（整合版）

---

## 0. 最快路径：两条命令搞定

如果你只想“先跑起来”，照下面做就够了（假设你已经在服务器上克隆好了项目）：

```bash
cd /data1/users/siyangming/nextflow_nf_core/riboseq.nf

# 1. 一次性下载 rRNA 数据库并生成本地清单
bash bin/setup_rrna_databases.sh

# 2. 使用带修复的配置继续运行（示例）
nextflow run . -c osa_config_FIXED.config -resume
```

如果运行顺利：

- `reference/` 目录会出现 8 个 `.fasta` 文件和一个 `rrna-db-local.txt`
- pipeline 不再报 rRNA 数据库相关的 “No such file or directory” / URL 错误

下面章节是**更详细的说明、检查清单和其它警告的修复**。

---

## 1. 问题背景与修复思路

### 1.1 遇到的典型错误

早期运行时典型报错类似：

```text
ERROR ~ No such file or directory: https://raw.githubusercontent.com/biocore/sortmerna/...
```

或在 rRNA 过滤相关步骤出现：

- “No such file or directory”  
- Nextflow 在参数校验阶段就失败（`checkIfExists` 无法对 URL 做文件存在性检查）

### 1.2 根本原因（概念级）

- pipeline 原本假设可以直接用网络 URL 作为 rRNA 数据库路径
- Nextflow 在运行前会对参数里给出的路径做 **文件存在性检查**（`checkIfExists: true`）
- 对本地路径没问题，但对 HTTP URL，它没法判断“文件是否存在”，于是直接判定为错误

### 1.3 解决方案思路

核心思路：

1. **预先把 rRNA 数据库下载到本地磁盘**（参考 SortMeRNA 官方数据库）
2. 用一个 **本地 manifest 文件（rrna-db-local.txt）** 列出所有 fasta 的绝对路径
3. 在 pipeline 配置中，让 `params.ribo_database_manifest` 指向这个 manifest
4. 之后每次运行都使用本地文件，不再依赖在线 URL

这个文档里的脚本和配置，就是帮你完成上述 1–3 步。

### 1.4 一张图理解修复前后

```text
修复前（失败）:
config → rrna-db-defaults.txt(一堆 URL) → SORTMERNA(checkIfExists: true) ❌

修复后（成功）:
setup_rrna_databases.sh
    → reference/*.fasta + rrna-db-local.txt(本地绝对路径)
config → ribo_database_manifest=rrna-db-local.txt → SORTMERNA(checkIfExists: true) ✅
```

---

## 2. 环境与预检（Pre-flight Check）

在服务器上确认：

- 你已经登录到服务器
- 项目路径：`/data1/users/siyangming/nextflow_nf_core/riboseq.nf/`
- 有网络访问 GitHub 的能力（首次下载需要）
- 磁盘剩余空间 ≥ 100 MB

参考检查命令：

```bash
cd /data1/users/siyangming/nextflow_nf_core/riboseq.nf/
pwd           # 应该显示上述路径
df -h .       # 确认剩余空间
ping github.com -c 3  # 简单网络测试（可选）
```

---

## 3. 一次性下载 rRNA 数据库并生成 manifest

> 对应原文档：CHECKLIST、RRNA_DATABASE_SETUP、QUICK_START_FIX

### 3.1 运行 setup 脚本

在项目根目录：

```bash
cd /data1/users/siyangming/nextflow_nf_core/riboseq.nf

chmod +x bin/setup_rrna_databases.sh    # 如已可执行可省略
bash bin/setup_rrna_databases.sh
```

脚本会做的事：

1. 自动定位项目根目录（`.../riboseq.nf`）
2. 在 `reference/` 目录下下载以下 8 个数据库（如果已存在则跳过）：
   - `rfam-5.8s-database-id98.fasta`
   - `rfam-5s-database-id98.fasta`
   - `silva-arc-16s-id95.fasta`
   - `silva-arc-23s-id98.fasta`
   - `silva-bac-16s-id90.fasta`
   - `silva-bac-23s-id98.fasta`
   - `silva-euk-18s-id95.fasta`
   - `silva-euk-28s-id98.fasta`
3. 在同一目录生成 manifest：`reference/rrna-db-local.txt`

典型成功输出中会看到：

```text
✓ All rRNA databases ready in /.../riboseq.nf/reference
Creating local database manifest: /.../riboseq.nf/reference/rrna-db-local.txt
✓ Created manifest file: /.../riboseq.nf/reference/rrna-db-local.txt
...
✓ Setup Complete!
```

### 3.2 手动验证下载结果

```bash
ls -lh reference/
cat reference/rrna-db-local.txt
du -sh reference/
```

期望：

- `reference/` 里有 8 个 `.fasta` 文件 + `rrna-db-local.txt`
- `du -sh reference/` 约 70–80 MB
- `rrna-db-local.txt` 里每一行都是一个绝对路径，例如：

```text
/data1/users/siyangming/nextflow_nf_core/riboseq.nf/reference/rfam-5.8s-database-id98.fasta
...
```

### 3.3 如果 setup 脚本失败

常见原因与处理：

- **Python 或 wget 不可用**
  - 确认 `python3`、`wget` 在 PATH 中
  - 或手动运行 Python 版本：

    ```bash
    python3 bin/download_rrna_databases.py
    ```

- **网络问题**
  - 检查服务器是否能访问 `raw.githubusercontent.com`
  - 如有代理或防火墙，需要按环境处理

- **权限问题**
  - 确认有写 `reference/` 目录的权限：

    ```bash
    mkdir -p reference
    touch reference/test.txt && rm reference/test.txt
    ```

---

## 4. 在配置中使用本地 rRNA manifest

> 对应原文档：README_FIX、00_START_HERE、INDEX

### 4.1 推荐：使用带修复的配置文件

如果仓库中已经有 `osa_config_FIXED.config`，可以直接使用：

1. 备份原配置（可选）：

   ```bash
   cp osa_config.config osa_config.config.backup
   ```

2. 查看修复内容，确认其中有类似：

   ```groovy
   params {
       ...
       ribo_database_manifest = "/data1/users/siyangming/nextflow_nf_core/riboseq.nf/reference/rrna-db-local.txt"
       ...
   }
   ```

3. 之后运行时加上 `-c osa_config_FIXED.config` 即可。

### 4.2 手动在你自己的 config 中添加

如果你有自定义 config，而不想用固定文件，可以手动在 `params { }` 中加入一行：

```groovy
params {
    ...
    ribo_database_manifest = "/data1/users/siyangming/nextflow_nf_core/riboseq.nf/reference/rrna-db-local.txt"
    ...
}
```

然后用这个 config 运行，例如：

```bash
nextflow run . -c your_config.config -resume
```

### 4.3 命令行直接指定（可选）

你也可以在命令行直接加参数，而不改 config：

```bash
nextflow run . \
  -c your_config.config \
  --ribo_database_manifest /data1/users/siyangming/nextflow_nf_core/riboseq.nf/reference/rrna-db-local.txt \
  -resume
```

---

## 5. 重新运行并验证 pipeline

> 对应原文档：CHECKLIST、QUICK_START_FIX、00_START_HERE

### 5.1 先 dry-run（可选但推荐）

```bash
nextflow run . -c osa_config_FIXED.config -dry-run
```

- 如果只是参数/路径有问题，通常会在 dry-run 阶段就报错
- 正常的话，dry-run 会列出即将执行的流程，而不真正运行

### 5.2 正式运行 / 继续运行

```bash
nextflow run . -c osa_config_FIXED.config -resume
```

监控日志：

```bash
tail -f .nextflow.log
```

需要关注：

- 不应再出现 rRNA 数据库相关的 “No such file or directory”
- SortMeRNA 相关 process（例如 `SORTMERNA`）应能正常提交并完成

### 5.3 成功后的简单检查

- pipeline 正常完成，`nextflow log` 中 run 状态为 `COMPLETED`
- 结果目录中有 rRNA 过滤后的 reads
- MultiQC 报告中能看到 rRNA 去除的统计信息

---

## 6. 其它警告与常见问题合集

> 对应原文档：FIXES_AND_SOLUTIONS、INDEX

这里列出你在修复 rRNA 问题之后，可能仍然看到的一些 **warning**，以及处理建议。

### 6.1 样本表中“未识别的表头”

典型日志：

```text
WARN: Found the following unidentified headers in samplesheet_*.csv:
     - sample_description
     - pair
     - treatment
```

原因：

- nf-core 的 schema 只严格定义了前 5 列：
  - `sample`
  - `fastq_1`
  - `fastq_2`
  - `strandedness`
  - `type`
- 其它列对 schema 来说是“未知的”，所以给出 WARN

影响：

- **不影响 pipeline 运行**，只是这些列不会被 schema 校验

处理建议：

- 如果你确实需要这些列（例如做 TE 分析用的 `treatment`、`pair`），可以：
  - 保留这些列，忽略 warning（安全）
  - 或把实验设计信息迁到 `contrasts` 文件中
  - 或自行修改 schema（高级用法）

### 6.2 未定义参数（`salmon_index`、`skip_pseudo_alignment`、`sortmerna_index`）

典型日志：

```text
WARN: Access to undefined parameter `salmon_index`
WARN: Access to undefined parameter `skip_pseudo_alignment`
WARN: Access to undefined parameter `sortmerna_index`
```

含义：

- workflow 代码中访问了这些参数，但 config 里没有显式给默认值
- Nextflow 会给出 warning，但如果代码中做了 `null`/`false` 等默认处理，一般不会导致失败

建议配置（可加在 `nextflow.config` 的 `params` 中）：

```groovy
params {
    // Pseudo-alignment 相关
    pseudo_aligner        = null   // 或 'salmon'
    skip_pseudo_alignment = false
    salmon_index          = null

    // rRNA 过滤相关
    sortmerna_index       = null
}
```

如果你暂时不想进行 rRNA 去除，也可以在 config 中直接关闭：

```groovy
params {
    remove_ribo_rna = false
}
```

说明：

- 如果不提供 `salmon_index`：
  - 启用 pseudo alignment 时，pipeline 会自动构建 Salmon index
- 如果不提供 `sortmerna_index`：
  - 在 `remove_ribo_rna = true` 时，SortMeRNA index 会自动构建

### 6.3 `.first()` 运算符相关 warning

典型日志：

```text
WARN: The operator `first` is useless when applied to a value channel ...
```

原因：

- 在 value channel（只发出一个值的 channel）上使用 `.first()` 没有意义
- 属于 **代码风格/质量 warning**，对结果没有影响

作为用户可直接忽略；如果你在维护 pipeline 源码，可按原文档建议去掉这些 `.first()`。

---

## 7. 快速命令参考（Cheat Sheet）

综合所有文档中最常用的命令，整理如下，方便直接复制：

```bash
# 进入项目目录
cd /data1/users/siyangming/nextflow_nf_core/riboseq.nf/

# 一次性下载 rRNA 数据库并生成 manifest
bash bin/setup_rrna_databases.sh

# 查看下载结果
ls -lh reference/
cat reference/rrna-db-local.txt
du -sh reference/

# 使用带修复配置 dry-run（可选）
nextflow run . -c osa_config_FIXED.config -dry-run

# 正式运行 / 继续运行
nextflow run . -c osa_config_FIXED.config -resume

# 监控日志
tail -f .nextflow.log

# 查看历史运行状态
nextflow log

# 清理失败的 run（如有需要）
nextflow clean -f
```

---

## 8. 最终验证清单

当你认为 rRNA 相关问题已经完全解决时，可以对照这份清单：

- [ ] `reference/` 目录存在  
- [ ] `reference/` 中有 8 个 `.fasta` 文件，总大小约 70–80 MB  
- [ ] 存在 `reference/rrna-db-local.txt` 且内容为绝对路径  
- [ ] 配置中 `params.ribo_database_manifest` 或命令行参数指向该 manifest  
- [ ] pipeline 能顺利通过参数校验阶段，不再报 URL / rRNA 数据库相关错误  
- [ ] SortMeRNA（或相应 rRNA 过滤步骤）能正常提交并完成  
- [ ] MultiQC 报告中出现 rRNA 去除统计  
- [ ] pipeline 整体运行状态为 `COMPLETED`

全部打勾 ✅ 之后，可以认为 **rRNA 数据库相关问题已彻底解决**。

---

## 9. 后续建议

- 如果还看到其它类型的 warning / error，可参考原 `FIXES_AND_SOLUTIONS.md` 中对其它问题的说明
- 建议把本文件保存下来，作为将来重新部署或给同事讲解时的统一参考

祝你的 Ribo-seq 分析顺利运行！🚀
