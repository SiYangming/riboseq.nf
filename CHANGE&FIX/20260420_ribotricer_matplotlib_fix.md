# 2026-04-20: Ribotricer Matplotlib 缓存权限错误修复

## 问题描述
在使用 `ribotricer detect-orfs` 模块执行时，程序崩溃并抛出以下警告与错误：
```text
Matplotlib created a temporary config/cache directory at /tmp/matplotlib-slrq0f28 because the default path (/.config/matplotlib) is not a writable directory; it is highly recommended to set the MPLCONFIGDIR environment variable to a writable directory, in particular to speed up the import of Matplotlib and to better support multiprocessing.
```
最终导致进程以退出码 `1` 失败，工作流中断。

## 原因分析
`matplotlib`（Ribotricer 用来生成 metagene 图表的 Python 库）在 Docker/Singularity 容器中运行时，其默认的配置和缓存目录 (`/.config/matplotlib`) 通常是只读的。虽然它尝试在 `/tmp` 下创建临时目录，但在并发处理（multiprocessing）或特定 HPC 容器环境的严格挂载权限下，这种自动回退机制可能会遭遇读写冲突，从而导致程序崩溃。

## 解决方案
修改了 `/modules/nf-core/ribotricer/detectorfs/main.nf` 中的执行脚本。在调用 `ribotricer` 命令之前，显式创建一个独立的临时目录并赋值给 `MPLCONFIGDIR` 环境变量：

```bash
export MPLCONFIGDIR=\$(mktemp -d)
```

这样确保了每次执行该任务时，`matplotlib` 都有一个专属的、可写的缓存目录，彻底避开了容器内的权限冲突并完美支持了多线程。

## 影响范围
- `/modules/nf-core/ribotricer/detectorfs/main.nf`