features {os.windows}

package mmapcj

import std.unittest.*
import std.unittest.testmacro.*

@Test
public class MmapFileTests {
    @TestCase
    public func testWriteAndRead(): Unit {
        let path = "/tmp/mmapcj_test_write_read.tmp"
        let size: Int64 = 4096
        let mf = MmapFile(path, size)
        let data = "Hello mmap!".toArray()
        mf.write(data, 0)
        let readBack = mf.read(0, data.size)
        @Expect(data, readBack)
        mf.close()
    }

    @TestCase
    public func testSync(): Unit {
        let path = "/tmp/mmapcj_test_sync.tmp"
        let size: Int64 = 4096
        let mf = MmapFile(path, size)
        mf.write("sync test".toArray(), 0)
        mf.sync()
        let readBack = mf.read(0, 9)
        @Expect("sync test".toArray(), readBack)
        mf.close()
    }

    @TestCase
    public func testClosed(): Unit {
        let path = "/tmp/mmapcj_test_closed.tmp"
        let mf = MmapFile(path, 4096)
        @Expect(false, mf.closed)
        mf.close()
        @Expect(true, mf.closed)
    }

    @TestCase
    public func testReadOnly(): Unit {
        let path = "/tmp/mmapcj_test_readonly.tmp"
        let mf = MmapFile(path, 4096)
        mf.write("data".toArray(), 0)
        mf.close()

        let ro = MmapFile(path, 4096, readOnly: true)
        let data = ro.read(0, 4)
        @Expect("data".toArray(), data)
        ro.close()
    }

    @TestCase
    public func testReadWriteAtOffset(): Unit {
        let path = "/tmp/mmapcj_test_offset.tmp"
        let size: Int64 = 4096
        let mf = MmapFile(path, size)
        mf.write("DEF".toArray(), 256)
        mf.write("ABC".toArray(), 0)
        mf.write("GHI".toArray(), 512)
        let part1 = mf.read(0, 3)
        let part2 = mf.read(256, 3)
        let part3 = mf.read(512, 3)
        @Expect("ABC".toArray(), part1)
        @Expect("DEF".toArray(), part2)
        @Expect("GHI".toArray(), part3)
        mf.close()
    }

    @TestCase
    public func testOutOfBounds(): Unit {
        let path = "/tmp/mmapcj_test_oob.tmp"
        let mf = MmapFile(path, 128)
        mf.close()
    }
}
