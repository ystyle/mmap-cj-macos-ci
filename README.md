# mmap-cj

跨平台内存映射文件库，支持 Linux、macOS、Windows。

## 功能

- 跨平台 API（common/specific 特性）
- 内存映射文件读写
- 数据同步到磁盘（msync/FlushViewOfFile）
- 自动资源管理

## 安装

```toml
[dependencies]
mmapcj = { git = "https://atomgit.com/ystyle/mmap-cj" }
```

## 使用

```cangjie
import mmapcj.MmapFile

// 创建内存映射文件
let mmapFile = MmapFile("/path/to/file", 1024 * 1024)  // 1MB

// 写入数据
mmapFile.write("Hello World".toArray(), 0)

// 同步到磁盘
mmapFile.sync()

// 读取数据
let data = mmapFile.read(0, 11)
println(String.fromUtf8(data))

// 关闭
mmapFile.close()
```

## API

### MmapFile

| 方法 | 说明 |
|------|------|
| `init(path, size, readOnly!)` | 创建/打开映射文件 |
| `write(data, offset)` | 写入数据 |
| `read(offset, len)` | 读取数据 |
| `sync()` | 同步到磁盘 |
| `close()` | 关闭映射 |
| `size` | 映射大小 |
| `path` | 文件路径 |
| `closed` | 是否已关闭 |

## 平台实现

| 平台 | API |
|------|-----|
| Linux | mmap/munmap/msync |
| macOS | mmap/munmap/msync |
| Windows | CreateFileMapping/MapViewOfFile/FlushViewOfFile |

## 测试

```shell
cjpm test
```

## 许可证

Apache-2.0