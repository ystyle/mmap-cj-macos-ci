features {os.windows}

package mmapcj

/**
 * Windows mmap 实现
 * 
 * Windows 使用 CreateFileMapping/MapViewOfFile API
 */

// Windows 常量
private const PAGE_READONLY: UInt32 = 0x02
private const PAGE_READWRITE: UInt32 = 0x04
private const PAGE_WRITECOPY: UInt32 = 0x08

private const FILE_MAP_READ: UInt32 = 0x04
private const FILE_MAP_WRITE: UInt32 = 0x02
private const FILE_MAP_ALL_ACCESS: UInt32 = 0xF001F

private const GENERIC_READ: UInt32 = 0x80000000
private const GENERIC_WRITE: UInt32 = 0x40000000
private const CREATE_ALWAYS: UInt32 = 2
private const OPEN_EXISTING: UInt32 = 3
private const FILE_ATTRIBUTE_NORMAL: UInt32 = 0x80

// FFI 函数 (Windows API)
@FastNative
foreign func CreateFileA(lpFileName: CPointer<UInt8>, dwDesiredAccess: UInt32, dwShareMode: UInt32, lpSecurityAttributes: CPointer<Unit>, dwCreationDisposition: UInt32, dwFlagsAndAttributes: UInt32, hTemplateFile: CPointer<Unit>): CPointer<Unit>

@FastNative
foreign func CreateFileMappingA(hFile: CPointer<Unit>, lpAttributes: CPointer<Unit>, flProtect: UInt32, dwMaximumSizeHigh: UInt32, dwMaximumSizeLow: UInt32, lpName: CPointer<UInt8>): CPointer<Unit>

@FastNative
foreign func MapViewOfFile(hFileMappingObject: CPointer<Unit>, dwDesiredAccess: UInt32, dwFileOffsetHigh: UInt32, dwFileOffsetLow: UInt32, dwNumberOfBytesToMap: UIntNative): CPointer<Unit>

@FastNative
foreign func FlushViewOfFile(lpBaseAddress: CPointer<Unit>, dwNumberOfBytesToFlush: UIntNative): Int32

@FastNative
foreign func UnmapViewOfFile(lpBaseAddress: CPointer<Unit>): Int32

@FastNative
foreign func CloseHandle(hObject: CPointer<Unit>): Int32

@FastNative
foreign func memcpy(dest: CPointer<UInt8>, src: CPointer<UInt8>, n: UIntNative): CPointer<UInt8>

public specific class MmapFile {
    private let _path: String
    private let _size: Int64
    private var hMap: CPointer<Unit>
    private var addr: CPointer<Unit>
    private var hFile: CPointer<Unit>
    private var _closed: Bool
    
    public specific init(path: String, size: Int64, readOnly!: Bool) {
        this._path = path
        this._size = size
        this._closed = false
        this.hMap = CPointer<Unit>()
        this.addr = CPointer<Unit>()
        this.hFile = CPointer<Unit>()
        
        unsafe {
            initInternal(path, size, readOnly)
        }
    }
    
    private unsafe func initInternal(path: String, size: Int64, readOnly: Bool): Unit {
        let access = if (readOnly) { GENERIC_READ } else { GENERIC_READ | GENERIC_WRITE }
        let creation = if (readOnly) { OPEN_EXISTING } else { CREATE_ALWAYS }
        
        let pathHandle = acquireArrayRawData(path.toArray())
        this.hFile = CreateFileA(pathHandle.pointer, access, 0u32, CPointer<Unit>(), creation, FILE_ATTRIBUTE_NORMAL, CPointer<Unit>())
        releaseArrayRawData(pathHandle)
        
        if (hFile.isNull()) {
            throw MmapException("Failed to open file: ${path}")
        }
        
        let protect = if (readOnly) { PAGE_READONLY } else { PAGE_READWRITE }
        let mapAccess = if (readOnly) { FILE_MAP_READ } else { FILE_MAP_ALL_ACCESS }
        
        let sizeHigh = UInt32((size >> 32) & 0xFFFFFFFF)
        let sizeLow = UInt32(size & 0xFFFFFFFF)
        
        this.hMap = CreateFileMappingA(hFile, CPointer<Unit>(), protect, sizeHigh, sizeLow, CPointer<UInt8>())
        
        if (hMap.isNull()) {
            CloseHandle(hFile)
            throw MmapException("Failed to create file mapping: ${path}")
        }
        
        this.addr = MapViewOfFile(hMap, mapAccess, 0u32, 0u32, UIntNative(size))
        
        if (addr.isNull()) {
            CloseHandle(hMap)
            CloseHandle(hFile)
            throw MmapException("Failed to map view of file: ${path}")
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
            let ret = FlushViewOfFile(addr, UIntNative(_size))
            if (ret == 0) {
                throw MmapException("FlushViewOfFile failed")
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
                UnmapViewOfFile(addr)
            }
            if (!hMap.isNull()) {
                CloseHandle(hMap)
            }
            if (!hFile.isNull()) {
                CloseHandle(hFile)
            }
        }
        
        addr = CPointer<Unit>()
        hMap = CPointer<Unit>()
        hFile = CPointer<Unit>()
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

public specific class MmapException <: Exception {
    public specific init(message: String) {
        super(message)
    }
}