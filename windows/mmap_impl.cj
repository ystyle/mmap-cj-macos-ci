features {os.windows}

package mmapcj

private const PAGE_READONLY: UInt32 = 0x02
private const PAGE_READWRITE: UInt32 = 0x04

private const FILE_MAP_READ: UInt32 = 0x04
private const FILE_MAP_ALL_ACCESS: UInt32 = 0xF001F

private const GENERIC_READ: UInt32 = 0x80000000
private const GENERIC_WRITE: UInt32 = 0x40000000
private const CREATE_ALWAYS: UInt32 = 2
private const OPEN_EXISTING: UInt32 = 3
private const OPEN_ALWAYS: UInt32 = 4
private const FILE_ATTRIBUTE_NORMAL: UInt32 = 0x80

@FastNative
foreign func CreateFileW(lpFileName: CPointer<UInt16>, dwDesiredAccess: UInt32, dwShareMode: UInt32, lpSecurityAttributes: CPointer<Unit>, dwCreationDisposition: UInt32, dwFlagsAndAttributes: UInt32, hTemplateFile: CPointer<Unit>): CPointer<Unit>

@FastNative
foreign func CreateFileMappingW(hFile: CPointer<Unit>, lpAttributes: CPointer<Unit>, flProtect: UInt32, dwMaximumSizeHigh: UInt32, dwMaximumSizeLow: UInt32, lpName: CPointer<UInt16>): CPointer<Unit>

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

private func utf8ToUtf16(s: String): Array<UInt16> {
    let bytes = s.toArray()
    let n = bytes.size

    var count: Int64 = 0
    var i: Int64 = 0
    while (i < n) {
        let b = UInt32(bytes[i])
        if ((b & UInt32(0x80)) == UInt32(0)) {
            i += 1
        } else if ((b & UInt32(0xE0)) == UInt32(0xC0)) {
            i += 2
        } else if ((b & UInt32(0xF0)) == UInt32(0xE0)) {
            i += 3
        } else {
            i += 4
            count += 1
        }
        count += 1
    }

    let result = Array<UInt16>(count + 1, repeat: UInt16(0))

    i = 0
    var j: Int64 = 0
    while (i < n) {
        let b0 = UInt32(bytes[i])
        if ((b0 & UInt32(0x80)) == UInt32(0)) {
            result[j] = UInt16(b0)
            i += 1
        } else if ((b0 & UInt32(0xE0)) == UInt32(0xC0)) {
            let b1 = UInt32(bytes[i + 1])
            let cp = (b0 & UInt32(0x1F)) << 6 | (b1 & UInt32(0x3F))
            result[j] = UInt16(cp)
            i += 2
        } else if ((b0 & UInt32(0xF0)) == UInt32(0xE0)) {
            let b1 = UInt32(bytes[i + 1])
            let b2 = UInt32(bytes[i + 2])
            let cp = (b0 & UInt32(0x0F)) << 12 | (b1 & UInt32(0x3F)) << 6 | (b2 & UInt32(0x3F))
            result[j] = UInt16(cp)
            i += 3
        } else {
            let b1 = UInt32(bytes[i + 1])
            let b2 = UInt32(bytes[i + 2])
            let b3 = UInt32(bytes[i + 3])
            let cp = (b0 & UInt32(0x07)) << 18 | (b1 & UInt32(0x3F)) << 12 | (b2 & UInt32(0x3F)) << 6 | (b3 & UInt32(0x3F))
            let cp2 = cp - UInt32(0x10000)
            result[j] = UInt16(UInt32(0xD800) | (cp2 >> 10))
            j += 1
            result[j] = UInt16(UInt32(0xDC00) | (cp2 & UInt32(0x3FF)))
            i += 4
        }
        j += 1
    }

    result
}

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
        // 注意：用 OPEN_ALWAYS 而非 CREATE_ALWAYS —— 后者会清空已存在文件的内容；
        // 读写打开必须保留既有内容（复用映射文件、崩溃恢复依赖这一点），
        // 文件大小随后由 SetEndOfFile 统一调整。
        let creation = if (readOnly) { OPEN_EXISTING } else { OPEN_ALWAYS }

        let utf16 = utf8ToUtf16(path)
        let pathHandle = acquireArrayRawData(utf16)
        this.hFile = CreateFileW(CPointer<UInt16>(pathHandle.pointer), access, 0u32, CPointer<Unit>(), creation, FILE_ATTRIBUTE_NORMAL, CPointer<Unit>())
        releaseArrayRawData(pathHandle)
        
        if (hFile.isNull()) {
            throw MmapException("Failed to open file: ${path}")
        }
        
        let protect = if (readOnly) { PAGE_READONLY } else { PAGE_READWRITE }
        let mapAccess = if (readOnly) { FILE_MAP_READ } else { FILE_MAP_ALL_ACCESS }
        
        let sizeHigh = UInt32((size >> 32) & 0xFFFFFFFF)
        let sizeLow = UInt32(size & 0xFFFFFFFF)
        
        this.hMap = CreateFileMappingW(hFile, CPointer<Unit>(), protect, sizeHigh, sizeLow, CPointer<UInt16>())
        
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
                FlushViewOfFile(addr, UIntNative(_size))
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

