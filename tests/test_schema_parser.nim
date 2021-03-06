import strutils
import math
import times

import nimdata
import nimdata/utils
import nimdata/schema_parser

when (NimMajor, NimMinor, NimPatch) > (0, 18, 0):
  import sugar except collect
else:
  import future

UnitTestSuite("Schema parser"):
  test "skipPastSep -- empty":
    var i = 0
    var hitEnd = false
    let s = "test"
    skipPastSep(s, i, hitEnd, ';')
    check i == s.len
    check hitEnd == true

  test "skipPastSep -- regular":
    var i = 0
    var hitEnd = false
    let s = "hello;world;test"
    skipPastSep(s, i, hitEnd, ';')
    check s[i] == 'w'
    skipPastSep(s, i, hitEnd, ';')
    check s[i] == 't'
    skipPastSep(s, i, hitEnd, ';')
    check i == s.len
    check hitEnd == true

  test "skipPastSep -- pure separators":
    var i = 0
    var hitEnd = false
    let s = ";;;"
    skipPastSep(s, i, hitEnd, ';')
    check s[i] == ';'
    skipPastSep(s, i, hitEnd, ';')
    check s[i] == ';'
    skipPastSep(s, i, hitEnd, ';')
    check i == s.len
    check hitEnd == false
    skipPastSep(s, i, hitEnd, ';')
    check i == s.len
    check hitEnd == true

  test "Schema type definition":
    const schema = [
      strCol("columnA"),
      intCol("columnB"),
      floatCol("columnC"),
    ]
    type
      MyType = schemaType(schema)
    let parser = schemaParser(schema, ';')
    let result: MyType = parser("1;2;3.5")
    proc filterFunc(x: MyType): bool = x.columnA == "1"
    check:
      DF.fromSeq(@["1;2;3.5"])
        .map(parser)
        .filter(filterFunc)
        .count() == 1

  test "Mixed columns":
    const schema = [
      strCol("columnA"),
      intCol("columnB"),
      floatCol("columnC"),
    ]
    let parser = schemaParser(schema, ';')
    let result = parser("1;2;3.5")
    check result == (columnA: "1", columnB: 2i64, columnC: 3.5)

  test "Mixed columns (different separator)":
    const schema = [
      strCol("columnA"),
      intCol("columnB"),
      floatCol("columnC"),
    ]
    let parser1 = schemaParser(schema, ',')
    let parser2 = schemaParser(schema, sep=',')
    check parser1("1,2,3.5") == (columnA: "1", columnB: 2i64, columnC: 3.5)
    check parser2("1,2,3.5") == (columnA: "1", columnB: 2i64, columnC: 3.5)

  # ---------------------------------------------------------------------------
  # string
  # ---------------------------------------------------------------------------

  test "Pure string column (1)":
    const schema = [
      strCol("columnA"),
    ]
    let parser = schemaParser(schema, ';')
    check:
      parser("hello") == (columnA: "hello")
      parser("") == (columnA: "")
      parser(" ") == (columnA: " ")
      parser(";") == (columnA: "") # do we want to support this or error?
      parser(" ;") == (columnA: " ") # do we want to support this or error?

  test "Pure string column (2)":
    const schema = [
      strCol("columnA"),
      strCol("columnB"),
    ]
    let parser = schemaParser(schema, ';')
    check:
      parser("hello;world") == (columnA: "hello", columnB: "world")

      parser(";world") == (columnA: "", columnB: "world")
      parser("hello;") == (columnA: "hello", columnB: "")
      parser(";") == (columnA: "", columnB: "")

      parser(" ;world") == (columnA: " ", columnB: "world")
      parser("hello; ") == (columnA: "hello", columnB: " ")
      parser(" ; ") == (columnA: " ", columnB: " ")

  test "Pure string column (3)":
    const schema = [
      strCol("columnA"),
      strCol("columnB"),
      strCol("columnC"),
    ]
    let parser = schemaParser(schema, ';')
    check:
      parser("hello;world;2") == (columnA: "hello", columnB: "world", columnC: "2")
      parser(";;;") == (columnA: "", columnB: "", columnC: "")
      parser(" ; ; ") == (columnA: " ", columnB: " ", columnC: " ")

  test "Pure string column (stripQuotes)":
    const schema = [
      strCol("columnA"),
      strCol("columnB", stripQuotes = true)
    ]
    let parser = schemaParser(schema, ';')
    check:
      parser("hello;world") == (columnA: "hello", columnB: "world")
      parser("\"hello\";\"world\"") == (columnA: "\"hello\"", columnB: "world")
      parser("'hello';'world'") == (columnA: "'hello'", columnB: "world")

  # ---------------------------------------------------------------------------
  # int
  # ---------------------------------------------------------------------------

  test "Pure int column (1)":
    const schema = [
      intCol("columnA"),
    ]
    let parser = schemaParser(schema, ';')
    check:
      parser("0") == (columnA: 0i64)
      parser("+0") == (columnA: 0i64)
      parser("-0") == (columnA: 0i64)
      parser(" 0") == (columnA: 0i64)
      parser("0 ") == (columnA: 0i64)
      parser("0;") == (columnA: 0i64)
      parser("+123467890") == (columnA: +123467890i64)
      parser("-123467890") == (columnA: -123467890i64)
      parser("0042") == (columnA: 42i64)

  test "Pure int column (2)":
    const schema = [
      intCol("columnA"),
      intCol("columnB"),
    ]
    let parser = schemaParser(schema, ';')
    check:
      parser("0;0") == (columnA: 0i64, columnB: 0i64)
      parser(" 0 ; 0 ") == (columnA: 0i64, columnB: 0i64)

  test "Pure int column (3)":
    const schema = [
      intCol("columnA"),
      intCol("columnB"),
      intCol("columnC"),
    ]
    let parser = schemaParser(schema, ';')
    check:
      parser("0;0;0") == (columnA: 0i64, columnB: 0i64, columnC: 0i64)

  test "Pure int column (parsers)":
    const schema = [
      intCol("columnBin", baseBin),
      intCol("columnOct", baseOct),
      intCol("columnDec", baseDec),
      intCol("columnHex", baseHex),
    ]
    let parser = schemaParser(schema, ';')
    check:
      parser("0b01;0o123;1000;0xabcde") == (columnBin: 0b01i64, columnOct: 0o123i64, columnDec: 1000i64, columnHex: 0xabcdei64)

  # ---------------------------------------------------------------------------
  # int of different sizes
  # ---------------------------------------------------------------------------
  test "Int column different sizes":
    const schema = [
      intCol("columnA"),
      int8Col("columnB"),
      int16Col("columnC"),
      int32Col("columnD"),
      uintCol("columnE"),
      uint8Col("columnF"),
      uint16Col("columnG"),
      uint32Col("columnH"),
    ]
    let parser = schemaParser(schema, ';')
    check:
      parser("122;123;124;125;126;127;128;129") == (columnA: 122i64,
                                                    columnB: 123i8,
                                                    columnC: 124i16,
                                                    columnD: 125i32,
                                                    columnE: 126u64,
                                                    columnF: 127u8,
                                                    columnG: 128u16,
                                                    columnH: 129u32)

  # ---------------------------------------------------------------------------
  # int8 of different bases
  # ---------------------------------------------------------------------------

  test "Pure int column of 8 bit, different base":
    const schema = [
      int8Col("columnBin", baseBin),
      int8Col("columnOct", baseOct),
      int8Col("columnDec", baseDec),
      int8Col("columnHex", baseHex),
    ]
    let parser = schemaParser(schema, ';')
    check:
      parser("0b01;0o123;123;0x1a") == (columnBin: 0b01i8,
                                        columnOct: 0o123i8,
                                        columnDec: 123i8,
                                        columnHex: 0x1ai8)

  # ---------------------------------------------------------------------------
  # uint64 of different bases
  # ---------------------------------------------------------------------------

  test "Pure uint column of 8 bit, different base":
    const schema = [
      uintCol("columnBin", baseBin),
      uintCol("columnOct", baseOct),
      uintCol("columnDec", baseDec),
      uintCol("columnHex", baseHex),
    ]
    let parser = schemaParser(schema, ';')
    check:
      parser("0b01;0o123;123;0xaf") == (columnBin: 0b01u64,
                                        columnOct: 0o123u64,
                                        columnDec: 123u64,
                                        columnHex: 0xafu64)

  # ---------------------------------------------------------------------------
  # uint8 of different bases
  # ---------------------------------------------------------------------------

  test "Pure uint column of 8 bit, different base":
    const schema = [
      uint8Col("columnBin", baseBin),
      uint8Col("columnOct", baseOct),
      uint8Col("columnDec", baseDec),
      uint8Col("columnHex", baseHex),
    ]
    let parser = schemaParser(schema, ';')
    check:
      parser("0b01;0o123;123;0xaf") == (columnBin: 0b01u8,
                                        columnOct: 0o123u8,
                                        columnDec: 123u8,
                                        columnHex: 0xafu8)


  # ---------------------------------------------------------------------------
  # float
  # ---------------------------------------------------------------------------

  test "Pure float column (1)":
    const schema = [
      floatCol("columnA"),
    ]
    let parser = schemaParser(schema, ';')
    check:
      parser("1.2") == (columnA: 1.2)
      parser(" 1.2 ") == (columnA: 1.2)
      parser(" +1.2 ") == (columnA: +1.2)
      parser(" -1.2 ") == (columnA: -1.2)
      parser(" 123e3 ") == (columnA: 123e3)
      parser(" .0001 ") == (columnA: 0.0001)
      parser("1.") == (columnA: 1.0)

  test "Pure float column (2)":
    const schema = [
      floatCol("columnA"),
      floatCol("columnB"),
    ]
    let parser = schemaParser(schema, ';')
    check:
      parser("1.2;1.2") == (columnA: 1.2, columnB: 1.2)
      parser(" 1.2 ; 1.2 ") == (columnA: 1.2, columnB: 1.2)
      parser("1.;1.") == (columnA: 1.0, columnB: 1.0)
      parser(".1;.1") == (columnA: 0.1, columnB: 0.1)

  test "Pure float column (3)":
    const schema = [
      floatCol("columnA"),
      floatCol("columnB"),
      floatCol("columnC"),
    ]
    let parser = schemaParser(schema, ';')
    check:
      parser("1.2;1.3;1.4") == (columnA: 1.2, columnB: 1.3, columnC: 1.4)

UnitTestSuite("Schema parser -- date parsing"):
  test "basic test":
    const schema = [
      dateCol("date")
    ]
    let parser = schemaParser(schema, ';')
    check parser("2017-01-01").date == times.parse("2017-01-01", "yyyy-MM-dd").toTime
