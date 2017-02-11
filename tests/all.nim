
import future

import ../src/nimdata
import ../src/nimdata_utils


UnitTestSuite("Schema Parser"):
  test "Parsing":
    const schema = [
      col(IntCol, "columnA"),
      col(IntCol, "columnB")
    ]
    let parser = schemaParser(schema)
    let result = parser("1;2")
    check result == (columnA: 1, columnB: 2)


UnitTestSuite("CachedDataFrame"):
  test "Construction from seq":
    let data = DF.fromSeq(@[1, 2, 3])
    check data.count() == 3

  test "Iteration":
    let data = DF.fromSeq(@[1, 2, 3])
    let iter1 = data.iter()
    var count = 0
    for x in iter1():   # data.iter does not work; the ugly `(data.iter)()` does, but inf-loops
      count += 1
    check count == 3

  test "Collect":
    let data = DF.fromSeq(@[1, 2, 3])
    let result = data.collect()
    check result.len == 3
    check result == @[1, 2, 3]

  test "Cache":
    let data = DF.fromSeq(@[1, 2, 3]).cache()
    let result = data.collect()
    check result.len == 3
    check result == @[1, 2, 3]


UnitTestSuite("MappedDataFrame"):
  test "Contstruction":
    let data = DF.fromSeq(@[1, 2, 3])
    let mapped1 = data.map(x => x*2)
    let mapped2 = DF.fromSeq(@[1, 2, 3]).map(x => x*2)
    let mapped3 = data.map(x => x*3).map(x => x*4)
    check mapped1.count() == 3
    check mapped2.count() == 3
    check mapped3.count() == 3

  test "Iteration":
    let data = DF.fromSeq(@[1, 2, 3]).map(x => x*2)
    let it = data.iter()
    var count = 0
    for x in it():   # data.iter does not work, it is the ugly `(data.iter)()` compiles but inf-loops
      count += 1
    check count == 3

  test "Collect":
    let data = DF.fromSeq(@[1, 2, 3]).map(x => x*2)
    let result = data.collect()
    check result.len == 3
    check result == @[2, 4, 6]

  test "Cache":
    let data = DF.fromSeq(@[1, 2, 3]).map(x => x*2).cache()
    let result = data.collect()
    check result.len == 3
    check result == @[2, 4, 6]

  test "Composition":
    let data = DF.fromSeq(@[1, 2, 3])
    let mapped = data.map(x => x*2)
    check mapped.collect() == @[2, 4, 6]
    check data.map(x => x*2).collect() == @[2, 4, 6]
    check data.map(x => x*2).map(x => x*2).collect() == @[4, 8, 12]
    check data.filter(x => x mod 2 == 1).map(x => x * 100).collect() == @[100, 300]

  test "Type Conversion":
    discard # check DF.fromSeq(@[1, 2, 3]).map(i => $i).collect() == @["1", "2", "3"]


UnitTestSuite("FilteredDataFrame"):
  test "Construction":
    let data = DF.fromSeq(@[1, 2, 3])
    let filtered1 = data.filter(x => x > 1)
    let filtered2 = DF.fromSeq(@[1, 2, 3]).filter(x => x > 1)
    let filtered3 = data.filter(x => x > 1).filter(x => x > 2)
    check filtered1.count() == 2
    check filtered2.count() == 2
    check filtered3.count() == 1

  test "Iteration":
    let data = DF.fromSeq(@[1, 2, 3]).filter(x => x > 1)
    let it = data.iter()
    var count = 0
    for x in it():
      count += 1
    check count == 2

  test "Collect":
    let data = DF.fromSeq(@[1, 2, 3]).filter(x => x > 1)
    let result = data.collect()
    check result.len == 2
    check result == @[2, 3]

  test "Cache":
    let data = DF.fromSeq(@[1, 2, 3]).filter(x => x > 1).cache()
    let result = data.collect()
    check result.len == 2
    check result == @[2, 3]

  test "Composition":
    let data = DF.fromSeq(@[1, 2, 3])
    check data.map(x => x * 100).filter(x => x mod 2 == 1).collect() == newSeq[int]()
    check data.filter(x => x mod 2 == 1).map(x => x * 100).collect() == @[100, 300]


UnitTestSuite("Indexed Operations"):
  test "Take":
    let data = DF.fromSeq(@[1, 2, 3]).take(2)
    check data.count() == 2
    check data.collect() == @[1, 2]
    check data.cache().count() == 2
    check data.map(x => x).count() == 2
    check data.filter(x => true).count() == 2

    check DF.fromSeq(@[1, 2, 3]).take(0).count() == 0
    check DF.fromSeq(@[1, 2, 3]).take(1).count() == 1
    check DF.fromSeq(@[1, 2, 3]).take(2).count() == 2
    check DF.fromSeq(@[1, 2, 3]).take(3).count() == 3
    check DF.fromSeq(@[1, 2, 3]).take(4).count() == 3

    check DF.fromSeq(@[1, 2, 3]).take(2).collect() == @[1, 2]
    check DF.fromSeq(@[1, 2, 3]).take(2).take(2).collect() == @[1, 2]
    check DF.fromSeq(@[1, 2, 3]).take(2).take(2).take(2).collect() == @[1, 2]

  test "Drop":
    let data = DF.fromSeq(@[1, 2, 3]).drop(2)
    check data.count() == 1
    check data.collect() == @[3]
    check data.cache().count() == 1
    check data.map(x => x).count() == 1
    check data.filter(x => true).count() == 1

    check DF.fromSeq(@[1, 2, 3]).drop(0).count() == 3
    check DF.fromSeq(@[1, 2, 3]).drop(1).count() == 2
    check DF.fromSeq(@[1, 2, 3]).drop(2).count() == 1
    check DF.fromSeq(@[1, 2, 3]).drop(3).count() == 0
    check DF.fromSeq(@[1, 2, 3]).drop(4).count() == 0

    check DF.fromSeq(@[1, 2, 3]).drop(1).collect() == @[2, 3]
    check DF.fromSeq(@[1, 2, 3]).drop(1).drop(1).collect() == @[3]
    check DF.fromSeq(@[1, 2, 3]).drop(1).drop(1).drop(1).collect() == newSeq[int]()
    check DF.fromSeq(@[1, 2, 3]).drop(1).drop(1).drop(1).drop(1).collect() == newSeq[int]()

  test "FilterWithIndex":
    check DF.fromSeq(@[1, 2, 3]).filterWithIndex((i, x) => i == 1).collect() == @[2]

  test "MapWithIndex":
    discard
    #check DF.fromSeq(@[1, 2, 3]).map(i => $i).collect() == @["1", "2", "3"]
    #check DF.fromSeq(@[1, 2, 3]).map(i => i == 2).collect() == @[false, true, false]
    #check DF.fromSeq(@[1, 2, 3]).mapWithIndex((i, x) => i == 1).collect() == @[false, true, false]


UnitTestSuite("Type specific"):
  test "DataFrame[string]":
    let data = DF.fromSeq(@["1", "2", "3"])
    check data.collect() == @["1", "2", "3"]
    check data.map(x => x & x).collect() == @["11", "22", "33"]

