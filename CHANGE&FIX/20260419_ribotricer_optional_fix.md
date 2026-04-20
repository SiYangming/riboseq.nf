# 2026-04-19: ribotricer detectorfs optional 参数修复

## 问题描述
在 Nextflow 中，当处理输出文件时，如果把 `optional: true` 参数写在 `path()` 函数内部：
```nextflow
path ('*_protocol.txt', optional: true)
```
当实际生成的文件不存在时，glob 模式匹配失败会 **先于** optional 检查，导致进程抛出“文件未找到”的错误，从而中断 Pipeline。

## 解决方案
将 `optional: true` 移到 `path()` 外部作为独立参数。并且为了遵循 Nextflow 的最佳实践，使用双引号包裹 glob 模式。

修改了 `/modules/nf-core/ribotricer/detectorfs/main.nf` 中的输出定义：

### 修复前的错误语法
```nextflow
tuple val(meta), path('*_protocol.txt', optional: true)             , emit: protocol
tuple val(meta), path('*_psite_offsets.txt', optional: true)        , emit: psite_offsets
```

### 修复后的正确语法
```nextflow
tuple val(meta), path("*_protocol.txt"), optional: true             , emit: protocol
tuple val(meta), path("*_psite_offsets.txt"), optional: true        , emit: psite_offsets
```

## 影响范围
- `/modules/nf-core/ribotricer/detectorfs/main.nf`

此修复保证了即使 `ribotricer` 在某些特定条件下未能输出 `*_protocol.txt` 或 `*_psite_offsets.txt`，Nextflow 也能正确将 channel 置为空并继续执行，而不会抛出严重错误。