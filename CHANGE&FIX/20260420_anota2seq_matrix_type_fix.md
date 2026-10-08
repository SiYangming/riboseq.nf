# Anota2seq 模块输入数据类型修复记录

## 日期
2026-04-20

## 模块路径
`modules/nf-core/anota2seq/anota2seqrun/templates/anota2seqrun.r`

## 1. 现象与报错
在 Ribo-seq 分析工作流中，如果通过配置参数覆盖 `anota2seqrun` 模块的内置标准化选项（即设置 `ext.args = '--normalize FALSE'`），用来接收 Salmon 输出的包含小数的 length-scaled counts 矩阵，进程会因为 R 对象的严格校验崩溃。

`.command.err` 中的报错内容如下：
```text
Error in validObject(.Object) : 
  invalid class “Anota2seqDataSet” object: 1: invalid object for slot "dataT" in class "Anota2seqDataSet": got class "data.frame", should be or extend class "matrix" 
invalid class “Anota2seqDataSet” object: 2: invalid object for slot "dataP" in class "Anota2seqDataSet": got class "data.frame", should be or extend class "matrix" 
```

## 2. 根本原因
`anota2seqDataSetFromMatrix` 函数内部在初始化 S4 对象 `Anota2seqDataSet` 时，如果开启了 `normalize = TRUE`，通常对输入的 R 表格容错率更高。但如果在禁用 normalize 的情况下，它对 `dataP` 和 `dataT` 的格式要求极其严格，要求输入必须是或继承自 R 的 `matrix` 类。

原 nf-core 模块模板代码在对读入的数据表进行切片时，仅仅执行了列过滤，保留了原有的 `data.frame` 类型：
```R
riboseq_data <- count.table[,riboseq_samples]
rnaseq_data <- count.table[,rnaseq_samples]
```
当这个 `data.frame` 对象传入 S4 构造函数时，引发了不可逾越的类型冲突。

## 3. 修复方案
在传递给 `anota2seqDataSetFromMatrix` 之前，显式调用 `as.matrix()` 将子集数据框转化为矩阵。

### 修改后的代码：
```R
################################################ 
## Run anota2seqRun() - Modified for matrix   ## 
################################################ 

# Separate matrix into riboseq and rnaseq data

riboseq_samples <- sample.sheet[[opt$sample_id_col]][sample.sheet[['type']] == 'riboseq']
rnaseq_samples <- sample.sheet[[opt$sample_id_col]][sample.sheet[['type']] == 'rnaseq']

if (! is.null(opt$samples_pairing_col)){
    riboseq_samples <- riboseq_samples[order(sample.sheet[riboseq_samples, opt$samples_pairing_col])]
    rnaseq_samples <- rnaseq_samples[order(sample.sheet[rnaseq_samples, opt$samples_pairing_col])]
}

riboseq_data <- as.matrix(count.table[,riboseq_samples])
rnaseq_data <- as.matrix(count.table[,rnaseq_samples])
```

## 4. 修复结果
修改后，Nextflow 会将更新后的模板下发给运行容器。在关闭 `normalize` 接受连续缩放值时，Anota2seq 不再抛出异常，工作流能够顺利完成翻译效率（Translational Efficiency）的统计和图表输出。