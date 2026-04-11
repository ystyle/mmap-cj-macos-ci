features {os.linux}

package mmapcj

import std.fs.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public func testMmapBasic(): Unit {
    let testPath = "/tmp/mmap_test_basic"
    
    if (exists(Path(testPath))) {
        remove(Path(testPath))
    }
    
    let mmapFile = MmapFile(testPath, 1024)
    
    let data = "Hello mmap!".toArray()
    mmapFile.write(data, 0)
    mmapFile.sync()
    
    let readData = mmapFile.read(0, data.size)
    let readStr = String.fromUtf8(readData)
    
    if (readStr != "Hello mmap!") {
        throw Exception("Read data mismatch: expected 'Hello mmap!', got '${readStr}'")
    }
    
    mmapFile.close()
    
    if (exists(Path(testPath))) {
        remove(Path(testPath))
    }
}

@Test
public func testMmapReadWrite(): Unit {
    let testPath = "/tmp/mmap_test_rw"
    
    if (exists(Path(testPath))) {
        remove(Path(testPath))
    }
    
    let mmapFile = MmapFile(testPath, 4096)
    
    mmapFile.write("Block1".toArray(), 0)
    mmapFile.write("Block2".toArray(), 100)
    mmapFile.write("Block3".toArray(), 200)
    
    mmapFile.sync()
    
    let data1 = mmapFile.read(0, 6)
    let data2 = mmapFile.read(100, 6)
    let data3 = mmapFile.read(200, 6)
    
    if (String.fromUtf8(data1) != "Block1") {
        throw Exception("Block1 mismatch")
    }
    if (String.fromUtf8(data2) != "Block2") {
        throw Exception("Block2 mismatch")
    }
    if (String.fromUtf8(data3) != "Block3") {
        throw Exception("Block3 mismatch")
    }
    
    mmapFile.close()
    
    if (exists(Path(testPath))) {
        remove(Path(testPath))
    }
}

@Test
public func testMmapExceedSize(): Unit {
    let testPath = "/tmp/mmap_test_exceed"
    
    if (exists(Path(testPath))) {
        remove(Path(testPath))
    }
    
    let mmapFile = MmapFile(testPath, 100)
    
    try {
        let largeData = Array<Byte>(200, repeat: 0)
        mmapFile.write(largeData, 0)
        throw Exception("Should have thrown MmapException")
    } catch (e: MmapException) {
        // 预期行为
    }
    
    mmapFile.close()
    
    if (exists(Path(testPath))) {
        remove(Path(testPath))
    }
}

@Test
public func testMmapClosed(): Unit {
    let testPath = "/tmp/mmap_test_closed"
    
    if (exists(Path(testPath))) {
        remove(Path(testPath))
    }
    
    let mmapFile = MmapFile(testPath, 1024)
    mmapFile.close()
    
    try {
        mmapFile.write("test".toArray(), 0)
        throw Exception("Should have thrown MmapException")
    } catch (e: MmapException) {
        // 预期行为
    }
    
    if (exists(Path(testPath))) {
        remove(Path(testPath))
    }
}

@Test
public func testMmapProperties(): Unit {
    let testPath = "/tmp/mmap_test_props"
    
    if (exists(Path(testPath))) {
        remove(Path(testPath))
    }
    
    let mmapFile = MmapFile(testPath, 2048)
    
    if (mmapFile.size != 2048) {
        throw Exception("Size mismatch: expected 2048, got ${mmapFile.size}")
    }
    
    if (mmapFile.path != testPath) {
        throw Exception("Path mismatch: expected '${testPath}', got '${mmapFile.path}'")
    }
    
    if (mmapFile.closed) {
        throw Exception("Should not be closed")
    }
    
    mmapFile.close()
    
    if (!mmapFile.closed) {
        throw Exception("Should be closed")
    }
    
    if (exists(Path(testPath))) {
        remove(Path(testPath))
    }
}