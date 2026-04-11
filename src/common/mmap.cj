@NonProduct
features {}

package mmapcj

/**
 * MmapFile - 内存映射文件接口
 *
 * 跨平台接口定义：
 * - Linux: mmap/munmap/msync
 * - macOS: mmap/munmap/msync
 * - Windows: CreateFileMapping/MapViewOfFile/FlushViewOfFile
 */
public common class MmapFile {
    /// 创建或打开一个内存映射文件
    /// path: 文件路径
    /// size: 映射大小（字节）
    /// readOnly: 是否只读模式（默认 false）
    public common init(path: String, size: Int64, readOnly!: Bool = false)
    
    /// 写入数据到指定偏移
    public common func write(data: Array<Byte>, offset: Int64): Unit
    
    /// 从指定偏移读取数据
    public common func read(offset: Int64, len: Int64): Array<Byte>
    
    /// 同步数据到磁盘
    public common func sync(): Unit
    
    /// 关闭映射
    public common func close(): Unit
    
    /// 映射大小
    public common prop size: Int64
    
    /// 文件路径
    public common prop path: String
    
    /// 是否已关闭
    public common prop closed: Bool
}

/**
 * MmapException - mmap 相关异常
 */
public common class MmapException <: Exception {
    public common init(message: String) {
        super(message)
    }
}