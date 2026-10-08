# 2026-04-19: RIBOTISH_PREDICT 模块 bug 修复

## 问题描述
在执行 `RIBOTISH_PREDICT` 模块时，Docker 容器中出现报错：`No input TIS data!`。这导致整个分析工作流失败。

## 原因分析
问题出在 `modules/nf-core/ribotish/predict/main.nf` 文件中，有三个相关的 bug：
1. **变量名拼写错误**：代码中使用了未定义的变量 `para_tis`，而实际传入的参数名是 `para_ti`。
2. **命令行参数拼写错误**：使用了错误的参数 `--tisparapara`，而实际应该是 `--tispara`。
3. **空列表判断逻辑错误**：当没有 TI-seq 数据时，工作流传入的是一个空的元组 `[[:],[],[]]`，因此 `bam_ti` 的值为 `[]`。在 Groovy/Nextflow 中，`if (bam_ti)` 对于空列表也会返回 `true`，导致代码依然尝试把空的数据传入并执行 TI-seq 的逻辑，最终触发 `No input TIS data!` 报错。

## 解决方案
在 `modules/nf-core/ribotish/predict/main.nf` 中对上述问题进行修复：

### 修复前的代码
```nextflow
    ribo_bam_cmd = ''
    ti_bam_cmd = ''
    if (bam_ribo){
        ribo_bam_cmd = "-b ${bam_ribo.join(',')}"
        if (para_ribo){
            ribo_bam_cmd += " --ribopara ${para_ribo.join(',')}"
        }
    }
    if (bam_ti){
        ti_bam_cmd = "-t ${bam_ti.join(',')}"
        if (para_tis){
            ti_bam_cmd += " --tisparapara  ${para_ti.join(',')}"
        }
    }
```

### 修复后的代码
```nextflow
    def ribo_bam_cmd = ''
    def ti_bam_cmd = ''
    if (bam_ribo && bam_ribo.size() > 0){
        ribo_bam_cmd = "-b ${bam_ribo.join(',')}"
        if (para_ribo && para_ribo.size() > 0){
            ribo_bam_cmd += " --ribopara ${para_ribo.join(',')}"
        }
    }
    if (bam_ti && bam_ti.size() > 0){
        ti_bam_cmd = "-t ${bam_ti.join(',')}"
        if (para_ti && para_ti.size() > 0){
            ti_bam_cmd += " --tispara ${para_ti.join(',')}"
        }
    }
```

## 影响范围
- `/modules/nf-core/ribotish/predict/main.nf`

修复后，只有真正提供了 TI-seq 数据时才会添加对应的 `-t` 及 `--tispara` 参数；当只有 Ribo-seq 数据时，Ribotish 可以正常工作并输出基于 3-nt 周期性的预测结果，不再报错。