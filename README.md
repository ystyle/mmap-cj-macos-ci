# mmap-cj

跨平台内存映射文件库，支持 Linux、macOS、Windows。

## 功能

- 跨平台 API（common/specific 特性）
- 内存映射文件读写
- 数据同步到磁盘（msync/FlushViewOfFile）
- 自动资源管理

## 构建

```shell
# Linux
cjpm build --enable-features=os.linux

# macOS
cjpm build --enable-features=os.darwin

# Windows（交叉编译）
cjpm build --enable-features=os.windows --target=x86_64-w64-mingw32
```

## 使用

```cangjie
import mmapcj.MmapFile

let mmapFile = MmapFile("/path/to/file", 1024 * 1024)

mmapFile.write("Hello World".toArray(), 0)
mmapFile.sync()

let data = mmapFile.read(0, 11)
println(String.fromUtf8(data))

mmapFile.close()
```

## API

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
| Windows | CreateFileW/CreateFileMappingW/FlushViewOfFile |

## 测试

```shell
# Linux
cjpm test --enable-features=os.linux

# macOS
cjpm test --enable-features=os.darwin

# Windows
cjpm test --enable-features=os.windows
```

## 项目结构

```
mmap-cj/
├── cjpm.toml
├── common/mmap.cj          公共接口定义
├── linux/mmap_impl.cj      Linux 实现
├── darwin/mmap_impl.cj     macOS 实现
└── windows/mmap_impl.cj    Windows 实现（UTF-16 路径）
```

## 许可证

Apache-2.0