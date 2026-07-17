@NonProduct
features {}

package mmapcj

public common class MmapFile {
    public common init(path: String, size: Int64, readOnly!: Bool = false)
    public common func write(data: Array<Byte>, offset: Int64): Unit
    public common func read(offset: Int64, len: Int64): Array<Byte>
    public common func sync(): Unit
    public common func close(): Unit
    public common prop size: Int64
    public common prop path: String
    public common prop closed: Bool
}

public class MmapException <: Exception {
    public init(message: String) {
        super(message)
    }
}