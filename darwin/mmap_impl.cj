features {os.darwin}

package mmapcj

/**
 * macOS mmap 实现
 * 
 * macOS 的 mmap API 与 Linux 几乎相同
 */

// mmap 常量 (macOS)
private const PROT_READ: Int32 = 0x1
private const PROT_WRITE: Int32 = 0x2
private const MAP_SHARED: Int32 = 0x01
private const MS_SYNC: Int32 = 0x0

private const O_RDONLY: Int32 = 0
private const O_RDWR: Int32 = 2
private const O_CREAT: Int32 = 0x200
private const O_TRUNC: Int32 = 0x400

// FFI 函数
@FastNative
foreign func mmap(addr: CPointer<Unit>, length: UIntNative, prot: Int32, flags: Int32, fd: Int32, offset: Int64): CPointer<Unit>

@FastNative
foreign func munmap(addr: CPointer<Unit>, length: UIntNative): Int32

@FastNative
foreign func msync(addr: CPointer<Unit>, length: UIntNative, flags: Int32): Int32

@FastNative
foreign func open(pathname: CPointer<UInt8>, flags: Int32, mode: UInt32): Int32

@FastNative
foreign func close(fd: Int32): Int32

@FastNative
foreign func ftruncate(fd: Int32, length: Int64): Int32

@FastNative
foreign func memcpy(dest: CPointer<UInt8>, src: CPointer<UInt8>, n: UIntNative): CPointer<UInt8>

public specific class MmapFile {
    private let _path: String
    private let _size: Int64
    private var addr: CPointer<Unit>
    private var fd: Int32
    private var _closed: Bool
    
    public specific init(path: String, size: Int64, readOnly!: Bool) {
        this._path = path
        this._size = size
        this._closed = false
        this.addr = CPointer<Unit>()
        this.fd = -1
        
        unsafe {
            initInternal(path, size, readOnly)
        }
    }
    
    private unsafe func initInternal(path: String, size: Int64, readOnly: Bool): Unit {
        let flags = if (readOnly) { O_RDONLY } else { O_RDWR | O_CREAT | O_TRUNC }
        
        let pathHandle = acquireArrayRawData(path.toArray())
        this.fd = open(pathHandle.pointer, flags, 0o644u32)
        releaseArrayRawData(pathHandle)
        
        if (fd < 0) {
            throw MmapException("Failed to open file: ${path}")
        }
        
        if (!readOnly && ftruncate(fd, size) < 0) {
            close(fd)
            throw MmapException("Failed to truncate file: ${path}")
        }
        
        let prot = if (readOnly) { PROT_READ } else { PROT_READ | PROT_WRITE }
        
        this.addr = mmap(CPointer<Unit>(), UIntNative(size), prot, MAP_SHARED, fd, 0)
        
        if (addr.isNull()) {
            close(fd)
            throw MmapException("Failed to mmap file: ${path}")
        }
    }
    
    public specific func write(data: Array<Byte>, offset: Int64): Unit {
        if (_closed) {
            throw MmapException("MmapFile is closed")
        }
        
        if (offset + data.size > _size) {
            throw MmapException("Write exceeds file size: offset=${offset}, len=${data.size}, size=${_size}")
        }
        
        unsafe {
            let dest = CPointer<UInt8>(addr) + offset
            let srcHandle = acquireArrayRawData(data)
            memcpy(dest, srcHandle.pointer, UIntNative(data.size))
            releaseArrayRawData(srcHandle)
        }
    }
    
    public specific func read(offset: Int64, len: Int64): Array<Byte> {
        if (_closed) {
            throw MmapException("MmapFile is closed")
        }
        
        if (offset + len > _size) {
            throw MmapException("Read exceeds file size: offset=${offset}, len=${len}, size=${_size}")
        }
        
        let result = Array<Byte>(len, repeat: 0)
        
        unsafe {
            let src = CPointer<UInt8>(addr) + offset
            let destHandle = acquireArrayRawData(result)
            memcpy(destHandle.pointer, src, UIntNative(len))
            releaseArrayRawData(destHandle)
        }
        
        result
    }
    
    public specific func sync(): Unit {
        if (_closed) {
            return
        }
        
        unsafe {
            let ret = msync(addr, UIntNative(_size), MS_SYNC)
            if (ret < 0) {
                throw MmapException("msync failed")
            }
        }
    }
    
    public specific func close(): Unit {
        if (_closed) {
            return
        }
        
        _closed = true
        
        unsafe {
            if (!addr.isNull()) {
                munmap(addr, UIntNative(_size))
            }
            if (fd >= 0) {
                close(fd)
            }
        }
        
        addr = CPointer<Unit>()
        fd = -1
    }
    
    public specific prop size: Int64 {
        get() { _size }
    }
    
    public specific prop path: String {
        get() { _path }
    }
    
    public specific prop closed: Bool {
        get() { _closed }
    }
}

