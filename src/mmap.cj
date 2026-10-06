package mmapcj

/**
 * mmap-cj：跨平台内存映射文件库（Linux / macOS / Windows）
 *
 * 平台实现位于同包的 mmap_linux.cj / mmap_darwin.cj / mmap_windows.cj，
 * 由 @When 条件编译按目标平台择一编译。
 */



public class MmapException <: Exception {
    public init(message: String) {
        super(message)
    }
}
