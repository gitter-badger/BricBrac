//
//  BricBracTests.swift
//  Bric-à-brac
//
//  Created by Marc Prud'hommeaux on 6/14/15.
//  Copyright © 2015 io.glimpse. All rights reserved.
//

import XCTest
import BricBrac
import JavaScriptCore

class BricBracTests : XCTestCase {

    func testAllocatonProfiling() {
        // json with unicode escapes
        // let path: String! = NSBundle(forClass: BricBracTests.self).pathForResource("test/profile/caliper.json", ofType: "")!

        // json no with escapes
        let path: String! = NSBundle(forClass: BricBracTests.self).pathForResource("test/profile/rap.json", ofType: "")!

//        let data: NSData! = NSData(contentsOfFile: path)!

        let contents: NSString! = try? NSString(contentsOfFile: path, encoding: NSUTF8StringEncoding)
        let scalars = Array((contents as String).unicodeScalars)

        var t = CFAbsoluteTimeGetCurrent()
        var c = 0
        while true {
            let _ = try? Bric.parse(scalars) // caliper.json: ~64/sec, rap.json: 105/sec
//            let _ = try? Bric.validate(scalars, options: .Strict) // caliper.json: ~185/sec, rap.json: ~380/sec
//            let _ = try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions()) // caliper.json: ~985/sec, rap.json: 1600/sec
            c++
            let t2 = CFAbsoluteTimeGetCurrent()
            if t2 > (t + 1.0) {
                print("parse-per-second: \(c)")
                t = t2
                c = 0
                break
            }
        }
    }

    func testEscaping() {
        func q(s: String)->String { return "\"" + s + "\"" }

        expectPass(q("\\/"), "/")
        expectPass(q("http:\\/\\/glimpse.io\\/"), "http://glimpse.io/")

        expectPass(q("\\n"), "\n")
        expectPass(q("\\r"), "\r")
        expectPass(q("\\t"), "\t")

        expectPass(q("\\\""), "\"")
        expectPass(q("\\\\"), "\\")

        expectPass(q("\\nX"), "\nX")
        expectPass(q("\\rYY"), "\rYY")
        expectPass(q("\\tZZZ"), "\tZZZ")

        expectPass(q("A\\nX"), "A\nX")
        expectPass(q("BB\\rYY"), "BB\rYY")

        expectPass(q("\\u002F"), "/")
        expectPass(q("\\u002f"), "/")

        expectPass("[ \"\\\"\" ]", ["\""])
        expectPass("[ \"x\", \"\\\"\" ]", ["x", "\""])

        expectPass(q("abc\\uD834\\uDD1Exyz"), "abc\u{0001D11E}xyz") // ECMA-404 section 9

        expectPass("[ { \"number\": 1 } ]", [[ "number": 1 ]])
        expectPass("[ { \"q\": \"\\\"\" } ]", [ [ "q": "\"" ]])

        do {
            let unescaped: Bric = "abc\"def"
            let escaped: String = "\"abc\\\"def\""

            let str = unescaped.stringify()
            XCTAssertEqual(escaped, str)

            let bric = try Bric.parse(escaped)
            XCTAssertEqual(unescaped, bric)
        } catch {
            XCTFail(String(error))
        }
    }

    func testBricBracPerson() {
        do {
            let p1 = try Person.brac(["name": "Marc", "age": 41, "male": true, "children": ["Bebe"]]) // , "children": []])
            print("p1: \(p1)")
            XCTAssertEqual(41, p1.age)

            XCTAssertEqual(p1.bric(), ["name": "Marc", "age": 41, "male": true, "children": ["Bebe"]])
            let p2 = try Person.brac(p1.bric())
            XCTAssertEqual(p1, p2, "Default bric equatability should work")

            let p3 = try Person.brac(["name": "Marc", "age": 41, "male": true, "children": ["Beatrix"]])
            XCTAssertNotEqual(p1, p3, "Default bric equatability should work")

        } catch {
            XCTFail("error deserializing: \(error)")
        }

        do {
            // test numeric overflow throwing exception
            let _ = try Person.brac(["name": "Marc", "age": .Num(Double(Int.min)), "male": true, "children": ["Bebe"]])
        } catch BracError.NumericOverflow {
            // as expected
        } catch {
            XCTFail("unexpected error when deserializing: \(error)")
        }

        do {
            try Person.brac(["name": "Marc", "male": true])
            XCTFail("should not have been able to deserialize with required fields")
        } catch BracError.MissingRequiredKey {
            // as expected
        } catch BracError.InvalidType {
            // FIXME: we should instead be throwing a MissingRequiredKey
        } catch {
            XCTFail("unexpected error when deserializing: \(error)")
        }
    }

    func testBricBracCompany() {
        do { // Human CEO
            let bric: Bric = ["name": "Apple", "ceo": ["name": "Tim", "age": 50, "male": true, "children": []], "status": "public", "customers": [["name": "Emily", "age": 41, "male": false, "children": ["Bebe"]]], "employees": [["name": "Marc", "age": 41, "male": true, "children": ["Bebe"]]], "subsidiaries": nil]

            XCTAssertEqual(bric["ceo"]?["name"], "Tim")
            XCTAssertEqual(bric["status"], "public")
            XCTAssertEqual(bric["employees"]?[0]?["children"]?[0], "Bebe")

            let c = try Company.brac(bric)

            let bric2 = c.bric()
            XCTAssertEqual(bric2["ceo"]?["name"], "Tim")
            XCTAssertEqual(bric2["status"], "public")
            XCTAssertEqual(bric2["employees"]?[0]?["children"]?[0], "Bebe")


            XCTAssertEqual(bric, bric2)
        } catch {
            XCTFail("unexpected error when deserializing: \(error)")
        }

        do { // Robot CEO
            let bric: Bric = ["name": "Apple", "ceo": "Stevebot", "customers": [["name": "Emily", "age": 41, "male": false, "children": ["Bebe"]]], "employees": [["name": "Marc", "age": 41, "male": true, "children": ["Bebe"]]], "status": "public", "subsidiaries": nil]
            let c = try Company.brac(bric)
            XCTAssertEqual(bric, c.bric())
        } catch {
            XCTFail("unexpected error when deserializing: \(error)")
        }

        do { // No CEO
            let bric: Bric = ["name": "Apple", "ceo": nil, "status": "public", "customers": [["name": "Emily", "age": 41, "male": false, "children": ["Bebe"]]], "employees": [["name": "Marc", "age": 41, "male": true, "children": ["Bebe"]]], "subsidiaries": nil]
            let c = try Company.brac(bric)
            XCTAssertEqual(bric, c.bric())
        } catch {
            XCTFail("unexpected error when deserializing: \(error)")
        }

    }

    func testReferenceCycles() {
        let company = Company(name: "Glimpse", ceo: nil, status: .`private`, customers: [], employees: [])
        company.subsidiaries = [company]
//        company.bric() // this would blow the stack because of object cycles
    }

    /// Tests wrapping behavior of BricLayer and BracLayer
    func testLayers() {
        do {
            do {
                let x = try Array<String>.brac(["foo", "bar"])
                XCTAssertEqual(x, ["foo", "bar"])
            }

            do {
                let x = try Optional<Array<Double>>.brac([1,2,3])
                XCTAssertEqual(x.bric(), [1,2,3])
            }

            do {
                let x = try Optional<Array<Double>>.brac(nil)
                if x != nil {
                    XCTFail("not nil")
                }
            }

            do {
                let x = try Array<Optional<Array<Bool>>>.brac([[false] as Bric, nil, [true, true] as Bric, [] as Bric])
                XCTAssertEqual(x.bric(), [[false], nil, [true, true], []])
            }

            do {
                let x = try Optional<Optional<Optional<Optional<Optional<Int>>>>>.brac(1.1)
                XCTAssertEqual(x.bric(), 1)
            }

            do {
                let x1 = try Optional<Int>.brac(nil)
                let x2 = try Optional<Optional<Int>>.brac(nil)
                let x3 = try Optional<Optional<Optional<Int>>>.brac(nil)
                let x4 = try Optional<Optional<Optional<Optional<Int>>>>.brac(nil)
                let x5 = try Optional<Optional<Optional<Optional<Optional<Int>>>>>.brac(nil)
                if x1 != nil || x2 != nil || x3 != nil || x4 != nil || x5 != nil {
                    XCTFail("bad value")
                } else {
                    x1.bric()
                    x2.bric()
                    x3.bric()
                    x4.bric()
                    x5.bric()
                }
            }

            do {
                let x1 = try Array<Int>.brac([1])
                let x2 = try Array<Array<Int>>.brac([[2, 1]])
                let x3 = try Array<Array<Array<Int>>>.brac([[[3, 2, 1]]])
                let x4 = try Array<Array<Array<Array<Int>>>>.brac([[[[4, 3, 2, 1]]]])
                let x5 = try Array<Array<Array<Array<Array<Int>>>>>.brac([[[[[5, 4, 3, 2, 1]]]]])
                XCTAssertEqual(x1, [1])
                XCTAssertEqual(x2, [[2,1]])
                XCTAssertEqual(x3, [[[3,2,1]]])
                XCTAssertEqual(x4, [[[[4,3,2,1]]]])
                XCTAssertEqual(x5, [[[[[5, 4, 3, 2, 1]]]]])

                XCTAssertEqual(x1.bric(), [1])
                XCTAssertEqual(x2.bric(), [[2,1]])
                XCTAssertEqual(x3.bric(), [[[3,2,1]]])
                XCTAssertEqual(x4.bric(), [[[[4,3,2,1]]]])
                XCTAssertEqual(x5.bric(), [[[[[5, 4, 3, 2, 1]]]]])
            }

            do {
                if let x = try Optional<CollectionOfOne<Double>>.brac([1.111]) {
                    XCTAssertEqual(x.first ?? 0, 1.111)
                    XCTAssertEqual(x.bric(), [1.111])
                } else {
                    XCTFail("error")
                }
            }

            do {
                if let x = try Optional<CollectionOfOne<Dictionary<String, Set<Int>>>>.brac([["foo": [1,1,2]]]) {
                    XCTAssertEqual(x.first ?? [:], ["foo": Set([1,2])])
                    x.bric()
                } else {
                    XCTFail("error")
                }
            }

            do {
                let bric: Bric = [["foo": 1.1], ["bar": 2.3]]

                let x = try Optional<Array<Dictionary<String, Double>>>.brac(bric)
                if let x = x {
                    XCTAssertEqual(x, [["foo": 1.1], ["bar": 2.3]])
                    x.bric()
                } else {
                    XCTFail()
                }
            }

            do {
                enum StringEnum : String, Bricable, Bracable { case foo, bar }
                let _ = try Array<Optional<StringEnum>>.brac(["foo", nil, "bar"])
            }

        } catch {
            XCTFail("unexpected error when wrapping in a BracLayer: \(error)")
        }

        // now do some that should fail
        do {
            let _ = try Array<String>.brac(["foo", 1])
            XCTFail("should have failed")
        } catch {
            // good
        }

        do {
            let _ = try Optional<Array<Double>>.brac([1,2,nil])
            XCTFail("should have failed")
        } catch {
            // good
        }

        do {
            let _ = try Optional<CollectionOfOne<Double>>.brac([1,2])
            XCTFail("should have failed")
        } catch {
            // good
        }

        do {
            let _ = try Optional<CollectionOfOne<Double>>.brac([])
            XCTFail("should have failed")
        } catch {
            // good
        }

        do {
            let _ = try Array<Int>.brac([[1]])
            XCTFail("should have failed")
        } catch {
            // good
        }

        do {
            let _ = try Array<Array<Int>>.brac([[[2, 1]]])
            XCTFail("should have failed")
        } catch {
            // good
        }

        do {
            let _ = try Array<Array<Array<Int>>>.brac([[[[3, 2, 1]]]])
            XCTFail("should have failed")
        } catch {
            // good
        }

        do {
            let _ = try Array<Array<Array<Array<Int>>>>.brac([[[[[4, 3, 2, 1]]]]])
            XCTFail("should have failed")
        } catch {
            // good
        }

        do {
            let _ = try Array<Array<Array<Array<Array<Int>>>>>.brac([[[[[[5, 4, 3, 2, 1]]]]]])
            XCTFail("should have failed")
        } catch {
            // good
        }

    }

    func testOutputNulls() {
        let bric: Bric = ["num": 1, "nul": nil]
        XCTAssertEqual("{\"num\":1,\"nul\":null}", bric.stringify())
    }

    func testBricBracSerialization() {
        let json = "{\"customers\":[{\"age\":41,\"male\":false,\"children\":[\"Bebe\"],\"name\":\"Emily\"}],\"employees\":[{\"age\":41,\"male\":true,\"children\":[\"Bebe\"],\"name\":\"Marc\"}],\"ceo\":{\"age\":50,\"male\":true,\"children\":[],\"name\":\"Tim\"},\"status\":\"public\",\"name\":\"Apple\"}"

        do {
            let bric: Bric = ["name": "Apple", "ceo": ["name": "Tim", "age": 50, "male": true, "children": []], "status": "public", "customers": [["name": "Emily", "age": 41, "male": false, "children": ["Bebe"]]], "employees": [["name": "Marc", "age": 41, "male": true, "children": ["Bebe"]]]]
            let str = bric.stringify()
            XCTAssertEqual(str, json)
        }

        do { // test quote serialization
            let bric: Bric = "abc\"def"
            let str = bric.stringify()
            XCTAssertEqual("\"abc\\\"def\"", str)
        }
    }

    func expectFail(s: String, _ msg: String? = nil, options: JSONParser.Options = .Strict, file: String = __FILE__, line: UInt = __LINE__) {
        do {
            try Bric.parse(s, options: options)
            XCTFail("Should have failed to parse", file: file, line: line)
        } catch {
            if let m = msg {
                XCTAssertEqual(m, String(error), file: file, line: line)
            }
        }
    }

    func expectPass(s: String, _ bric: Bric? = nil, options: JSONParser.Options = .Strict, file: String = __FILE__, line: UInt = __LINE__) {
        do {
            let b = try Bric.parse(s, options: options)
            if let bric = bric {
                XCTAssertEqual(bric, b, file: file, line: line)
            } else {
                // no comparison bric; just pass
            }
        } catch {
            XCTFail("\(error)", file: file, line: line)
        }
    }

    func testBricBracParsing() {
        func q(s: String)->String { return "\"" + s + "\"" }

        expectPass("1", 1)
        expectPass("1.0", 1.0)
        expectPass("1.1", 1.1)
        expectPass("-1.00100", -1.001)
        expectPass("1E+1", 10)
        expectPass("1E-1", 0.1)
        expectPass("1.0E+1", 10)
        expectPass("1.0E-1", 0.1)
        expectPass("1.2E+1", 12)
        expectPass("1.2E-1", 0.12)
        expectPass("1E+10", 1E+10)
        expectPass("1e-100", 1e-100)

        expectFail("-01234.56789", "Leading zero in number (line: 1 column: 12)")
        expectPass("-01234.56789", -01234.56789, options: .AllowLeadingZeros)

        expectFail("1 XXX", "Trailing content (line: 1 column: 3)")
        expectPass("1 XXX", 1, options: .AllowTrailingContent)

        expectFail("n")
        expectFail("nu")
        expectFail("nul")
        expectPass("null", .Nul)

        expectFail("t")
        expectFail("tr")
        expectFail("tru")
        expectPass("true", true)

        expectFail("f")
        expectFail("fa")
        expectFail("fal")
        expectFail("fals")
        expectPass("false", false)
        
        expectFail("truefalse", "Trailing content (line: 1 column: 5)")

        expectFail(",", "Comma found with no pending result (line: 1 column: 1)")
        expectFail("]", "Unmatched close array brace (line: 1 column: 1)")
        expectFail("}", "Unmatched close object brace (line: 1 column: 1)")
        expectFail(":", "Object key assignment outside of an object (line: 1 column: 1)")
        expectFail("[\"key\" :", "Object key assignment outside of an object (line: 1 column: 8)")


        expectFail("[truefalse]", "Character found with pending result value (line: 1 column: 6)")
        expectFail("[true1]", "Number found with pending result value (line: 1 column: 6)")
        expectFail("[1true]", "Character found with pending result value (line: 1 column: 3)")
        expectFail("[true\"ABC\"]", "String found with pending result value (line: 1 column: 6)")
        expectFail("[\"ABC\" true]", "Character found with pending result value (line: 1 column: 8)")
        expectFail("[\"a\"\"b\"]", "String found with pending result value (line: 1 column: 5)")
        expectFail("[\"a\"1\"b\"]", "Number found with pending result value (line: 1 column: 5)")
        expectFail("[\"a\"nu\"b\"]", "Character found with pending result value (line: 1 column: 5)")

        expectFail("[true", "Unclosed container (line: 1 column: 5)")
        expectFail("{", "Unclosed container (line: 1 column: 1)")
        expectFail("{\"qqq\"", "Unclosed container (line: 1 column: 6)")

        expectFail(q("abc\tdef"), "Strings may not contain tab characters (line: 1 column: 5)")
        expectFail(q("\n"), "Strings may not contain newlines (line: 2 column: 0)")

        expectPass("[\"abcéfg\", 123.4567]", ["abcéfg", 123.4567])
        expectPass("[123.4567]", [123.4567])
        expectPass("0", 0)
        expectPass("0.1", 0.1)
        expectPass("123.4567", 123.4567)
        expectPass("123.4567 ", 123.4567)
        expectPass("[[[[123.4567]]]]", [[[[123.4567]]]])
        expectPass("{\"foo\": \"bar\"}", ["foo": "bar"])
        expectPass("{\"foo\": 1}", ["foo": 1])
        expectPass("{\"foo\": null}", ["foo": nil])
        expectPass("{\"foo\": true}", ["foo": true])
        expectPass("{\"foo\": false}", ["foo": false])
        expectPass("{\"foo\": false, \"bar\": true}", ["foo": false, "bar": true])
        expectPass("{\"foo\": false, \"bar\": {\"a\": \"bcd\"}}", ["foo": false, "bar": ["a": "bcd"]])
        expectPass("{\"foo\": false, \"bar\": {\"a\": [\"bcd\"]}}", ["foo": false, "bar": ["a": ["bcd"]]])
        expectPass("{\"foo\": false, \"bar\": {\"a\": [\"bcd\"],\"b\":[]},\"baz\": 2}", ["foo": false, "bar": ["a": ["bcd"], "b": []], "baz": 2])

        expectPass("[1, \"a\", true]", [1, "a", true])
        expectPass("[  \r\n  \n  1  \n  \n  ,  \n  \t\n  \"a\"  \n  \n  ,  \r\t\n  \n  true  \t\t\r\n  \n  ]", [1, "a", true])
        expectFail("[1, \"a\", true,]", "Trailing comma (line: 1 column: 15)")

        expectPass("{\"customers\":[{\"age\":41,\"male\":false,\"children\":null,\"name\":\"Emily\"}],\"employees\":[null],\"ceo\":null,\"name\":\"Apple\"}")

        expectPass("{\"customers\":[{\"age\":41,\"male\":false,\"children\":[\"Bebe\"],\"name\":\"Emily\"}],\"employees\":[{\"age\":41,\"male\":true,\"children\":[\"Bebe\"],\"name\":\"Marc\"}],\"ceo\":{\"age\":50.01E+10,\"male\":true,\"children\":[],\"name\":\"Tim\"},\"name\":\"Apple\"}")

        expectFail("{\"Missing colon\" null}", "Invalid character within object start (line: 1 column: 18)")
        expectFail("{\"Extra colon\":: null}", "Object key assignment outside of an object (line: 1 column: 16)")
        expectFail("{\"Extra colon\"::: null}", "Object key assignment outside of an object (line: 1 column: 16)")

        expectFail("{{", "Object start within object start (line: 1 column: 2)")
        expectFail("{[", "Array start within object start (line: 1 column: 2)")
        expectFail("{x", "Invalid character within object start (line: 1 column: 2)")
        expectFail("[x", "Unrecognized token: x (line: 1 column: 2)")

        expectPass(q("a"), "a")
        expectPass(q("abc"), "abc")

        expectPass(q("/"), "/")
        expectPass(q("\\/"), "/")
        expectPass(q("http:\\/\\/glimpse.io\\/"), "http://glimpse.io/")

        expectPass(q("\\n"), "\n")
        expectPass(q("\\r"), "\r")
        expectPass(q("\\t"), "\t")

        expectPass(q("\\nX"), "\nX")
        expectPass(q("\\rYY"), "\rYY")
        expectPass(q("\\tZZZ"), "\tZZZ")

        expectPass(q("A\\nX"), "A\nX")
        expectPass(q("BB\\rYY"), "BB\rYY")
        expectPass(q("CCC\\tZZZ"), "CCC\tZZZ")

        expectPass(q("\\u002F"), "/")
        expectPass(q("\\u002f"), "/")

        expectPass(q("abc\\uD834\\uDD1Exyz"), "abc\u{0001D11E}xyz") // ECMA-404 section 9

        for char in ["X", "é", "\u{003}", "😡"] {
            expectPass(q(char), .Str(char))
        }
    }

    /// Verify that our serialization is compatible with NSJSONSerialization
    func testBricBracCocoaCompatNumbers() {
        compareCocoaParsing("1.2345678", msg: "fraction alone")
        compareCocoaParsing("1.2345678 ", msg: "fraction with trailing space")
        compareCocoaParsing("1.2345678\n", msg: "fraction with trailing newline")
        compareCocoaParsing("1.2345678\n\n", msg: "fraction with trailing newlines")

        compareCocoaParsing("1", msg: "number with no newline")
        compareCocoaParsing("1 ", msg: "number with trailing space")
        compareCocoaParsing("1\n", msg: "number with trailing newline")
        compareCocoaParsing("1\n\n", msg: "number with trailing newlines")

        compareCocoaParsing("0.1", msg: "fractional number with leading zero")
        compareCocoaParsing("1.234567890E+34", msg: "number with upper-case exponent")
        compareCocoaParsing("0.123456789e-12", msg: "number with lower-case exponent")

        compareCocoaParsing("[0e]", msg: "number with trailing e at end of array")
        compareCocoaParsing("[0e+]", msg: "number with trailing e+ at end of array")

        compareCocoaParsing("0.1", msg: "preceeding zero OK")
        compareCocoaParsing("01", msg: "preceeding zero should fail")
        compareCocoaParsing("01.23", msg: "preceeding zero should fail")
        compareCocoaParsing("01.01", msg: "preceeding zero should fail")
        compareCocoaParsing("01.0", msg: "preceeding zero should fail")
    }

    func profileJSON(str: String, count: Int, validate: Bool, cocoa: Bool, cf: Bool) throws {
        let scalars = Array((str as String).unicodeScalars)

        if let data = str.dataUsingEncoding(NSUTF8StringEncoding) {

            let js = CFAbsoluteTimeGetCurrent()
            for _ in 1...count {
                if cf {
                    let _ = try FoundationBricolage.parseJSON(scalars, options: JSONParser.Options.Strict)
//                    let nsobj = Unmanaged<NSObject>.fromOpaque(COpaquePointer(fbric.ptr)).takeRetainedValue()
                } else if cocoa {
                    let _: NSObject = try Bric.parseCocoa(scalars)
                } else if validate {
                    try Bric.validate(scalars, options: JSONParser.Options.Strict)
                } else {
                    try Bric.parse(scalars)
                }
            }
            let je = CFAbsoluteTimeGetCurrent()

            let cs = CFAbsoluteTimeGetCurrent()
            for _ in 1...count {
                try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments)
            }
            let ce = CFAbsoluteTimeGetCurrent()

            print((cf ? "CF" : cocoa ? "Cocoa" : validate ? "Validated" : "Fluent") + ": BricBrac: \(je-js) Cocoa: \(ce-cs) (\(Int(round((je-js)/(ce-cs))))x slower)")
        }
    }

    func parsePath(path: String, strict: Bool, file: String = __FILE__, line: UInt = __LINE__) throws -> Bric {
        let str = try NSString(contentsOfFile: path, encoding: NSUTF8StringEncoding)
        let bric = try Bric.parse(str as String, options: strict ? .Strict : .Lenient)

        // always check to ensure that our strinification matches that of JavaScriptCore
        compareJSCStringification(bric, msg: (path as NSString).lastPathComponent, file: file, line: line)
        return bric
    }

    func compareCocoaParsing(string: String, msg: String, file: String = __FILE__, line: UInt = __LINE__) {
        var cocoaBric: NSObject?
        var bricError: ErrorType?
        var cocoa: NSObject?
        var cocoaError: ErrorType?

        do {
            // NSJSONSerialization doesn't always ignore trailing spaces: http://openradar.appspot.com/21472364
            let str = string.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
            cocoa = try NSJSONSerialization.JSONObjectWithData(str.dataUsingEncoding(NSUTF8StringEncoding)!, options: NSJSONReadingOptions.AllowFragments) as? NSObject
        } catch {
            cocoaError = error
        }

        do {
            cocoaBric = try Bric.parseCocoa(string)
        } catch {
            bricError = error
        }

        switch (cocoaBric, cocoa, bricError, cocoaError) {
        case (.Some(let j), .Some(let c), _, _):
            if j != c {
//                dump(j)
//                dump(c)
                print(j)
                print(c)
//                assert(j == c)
            }
            XCTAssertTrue(j == c, "Parsed contents differed for «\(msg)»", file: file, line: line)
        case (_, _, .Some(let je), .Some(let ce)):
            // for manual inspection of error messages, change equality to inequality
            if String(je) == String(ce) {
                print("Bric Error «\(msg)»: \(je)")
                print("Cocoa Error «\(msg)»: \(ce)")
            }
            break
        case (_, _, _, .Some(let ce)):
            XCTFail("Cocoa failed/BricBrac passed «\(msg)»: \(ce)", file: file, line: line)
        case (_, _, .Some(let je), _):
            XCTFail("BricBrac failed/Cocoa passed «\(msg)»: \(je)", file: file, line: line)
        default:
            XCTFail("Unexpected scenario «\(msg)»", file: file, line: line)
        }
    }

    let ctx = JSContext()

    /// Asserts that Bric's stringify() exactly matches JavaScriptCore's JSON.stringify, with the following exceptions:
    ///
    /// * Key ordering is forced to be alphabetical (to compensate for the undefined key enumeration ordering of
    ///   Swift Dictionaries and JSC Objects)
    ///
    /// * We outputs exponential notation for some large integers, whereas JSC nevers appears to do so
    func compareJSCStringification(b: Bric, space: Int = 2, msg: String, file: String = __FILE__, line: UInt = __LINE__) {
        // JSC only allows dictionaries and arrays, so wrap any primitives in an array
        let bric: Bric = ["ob": b] // we just wrap everything in an array

        // key ordering in output is arbitrary depending on the underlying dictionary implementation,
        // and Swift and JavaScriptCore list keys in a different order; so to test this properly,
        // we need to serialize the swift key order the same as JavaScriptCore; we do this by
        // having the mapper query the JSContents for the order in which the keys would be output
        func mapper(dict: [String: Bric]) -> AnyGenerator<(String, Bric)> {
            return anyGenerator(Array(dict).sort({ kv1, kv2 in
                return kv1.0 < kv2.0
            }).generate())
        }

        let bstr = bric.stringify()

        let evaluated = ctx.evaluateScript("testOb = " + bstr)
        XCTAssertTrue(evaluated.isObject, "\(msg) parsed instance was not an object: \(bstr)", file: file, line: line)
        XCTAssertNil(ctx.exception, "\(msg) error evaluating brac'd string: \(ctx.exception)", file: file, line: line)

        let bricString = bric.stringify(space: space, mapper: mapper)

        let stringified = ctx.evaluateScript("JSON.stringify(testOb, function(key, value) { if (value === null || value === void(0) || value.constructor !== Object) { return value; } else { return Object.keys(value).sort().reduce(function (sorted, key) { sorted[key] = value[key]; return sorted; }, {}); } }, \(space))")
        if !stringified.isString {
            XCTFail("\(msg) could not stringify instance in JS context: \(ctx.exception)", file: file, line: line)
        } else {
            let str = stringified.toString()
            if bricString.containsString("e+") { // we differ in that we output exponential notation
                return
            }

            XCTAssertTrue(str == bricString, "\(msg) did not match:\n\(str)\n\(bricString)", file: file, line: line)
        }

    }

    func testNulNilEquivalence() {
        do {
            let j1 = Bric.Obj(["foo": "bar"])

            let j2 = Bric.Obj(["foo": "bar", "baz": nil])

            // the two Brics are not the same...
            XCTAssertNotEqual(j1, j2)

            // ... and the two underlying dictionaries are the same ...
            if case .Obj(let d1) = j1, .Obj(let d2) = j2 {
                XCTAssertNotEqual(d1, d2)
            }

            let j3 = Bric.Obj(["foo": "bar", "baz": .Nul])
            // the two Brics are the same...
            XCTAssertEqual(j2, j3)

            // ... and the two underlying dictionaries are the same ...
            if case .Obj(let d2) = j2, .Obj(let d3) = j3 {
                XCTAssertEqual(d2, d3)
            }

            print(j3.stringify())

        }
    }

    func testArraySubscripting() {
        var arr: Bric = [123, "abc", true]
        XCTAssertEqual(123, arr[0])
        XCTAssertEqual("abc", arr[1])
        XCTAssertEqual(true, arr[2])

        arr[0] = Int(456)
        XCTAssertEqual(456, arr[0])

        arr[0] = Bool(true)
        XCTAssertEqual(true, arr[0])

        arr[0] = String("yes")
        XCTAssertEqual("yes", arr[0])

        arr[0] = nil as String?
        XCTAssertEqual(Optional<String>.None, arr[0])

        arr[0] = Double(Int.max) + 100
        XCTAssertEqual(Int.max, arr[0])

        arr[0] = Double(Int.max) + 100
        XCTAssertEqual(Int.max, arr[0])

        arr[0] = 99.999
        XCTAssertEqual(99.999, arr[0])

        arr[6] = "out of bounds"
        arr[6] = nil as String?

        arr[2] = ["foo": [1,2,3]] as Dictionary<String, Bric>
        XCTAssertEqual(["foo": [1,2,3]] as Bric, arr[2])

        var copy = arr
        copy[100] = "abc" // shoud be a no-op
        XCTAssertEqual(arr.hashValue, copy.hashValue)

        copy[2]?["foo"]?[2] = 99
        XCTAssertNotEqual(arr.hashValue, copy.hashValue)

        copy += "xyz"
        XCTAssertEqual(copy, [99.999, "abc", ["foo": [1,2,99]], "xyz"])

    }

    func testKeyedSubscripting() {
        let val: Bric = ["key": "foo"]
        if let _: String = val["key"] {
        } else {
            XCTFail()
        }
    }

    func testBricAlter() {
        XCTAssertEqual("Bar", Bric.Str("Foo").alter { (_, _) in "Bar" })
        XCTAssertEqual(123, Bric.Str("Foo").alter { (_, _) in 123 })
        XCTAssertEqual([:], Bric.Arr([]).alter { (_, _) in [:] })

        XCTAssertEqual(["foo": 1, "bar": "XXX"], Bric.Obj(["foo": 1, "bar": 2]).alter {
            return $0 == [.Key("bar")] ? "XXX" : $1
        })

        do {
            let b1: Bric = [["foo": 1, "bar": 2], ["foo": 1, "bar": 2]]
            let b2: Bric = [["foo": 1, "bar": 2], ["foo": "XXX", "bar": "XXX"]]
            let path: Bric.Pointer = [.Index(1) ]
            XCTAssertEqual(b2, b1.alter { return $0.startsWith(path) && $0 != path ? "XXX" : $1 })
        }
    }

//    func testBricBracAround() {
//        do {
//            let x1: Array<String> = ["a", "b", "c"]
//            let x2 = try Array<String>.brac(x1.bric())
//            XCTAssertEqual(x1, x2)
//        } catch {
//            XCTFail("Round-trip error")
//        }
//    }

    func testJSONFormatting() {
        let json = "{\"abc\": 1.2233 , \"xyz\" :  \n\t\t[true,false, null]}  "
        let compact = "{\"abc\":1.2233,\"xyz\":[true,false,null]}"
        let pretty = "{\n  \"abc\" : 1.2233,\n  \"xyz\" : [\n    true,\n    false,\n    null\n  ]\n}"
        do {
            let p1 = try JSONParser.formatJSON(json)
            XCTAssertEqual(p1, json)

            let p2 = try JSONParser.formatJSON(json, indent: 0)
            XCTAssertEqual(p2, compact)

            let p3 = try JSONParser.formatJSON(json, indent: 2)
            XCTAssertEqual(p3, pretty)
        } catch {
            XCTFail(String(error))
        }
    }

    func testBricBracCompatability() {

        let fm = NSFileManager.defaultManager()
        do {
            if let folder = NSBundle(forClass: BricBracTests.self).pathForResource("test", ofType: "") {
                let types = try fm.contentsOfDirectoryAtPath(folder)
                XCTAssertEqual(types.count, 5) // data, jsonchecker, profile, schema
                for type in types {
                    let dir = (folder as NSString).stringByAppendingPathComponent(type)
                    let jsons = try fm.contentsOfDirectoryAtPath(dir)
                    for file in jsons {
                        do {
                            let fullPath = (dir as NSString).stringByAppendingPathComponent(file)

                            // first check to ensure that NSJSONSerialization's results match BricBrac's

                            if file.hasSuffix(".json") {

                                // make sure our round-trip validing parser works
                                let contents = try NSString(contentsOfFile: fullPath, encoding: NSUTF8StringEncoding) as String


                                do {
                                    let scalars = contents.unicodeScalars // quite a bit slower than operating on the array
                                    // let scalars = Array(contents.unicodeScalars)
                                    let roundTripped = try roundTrip(scalars)
                                    XCTAssertEqual(String(scalars), String(roundTripped))
                                } catch {
                                    // ignore parse errors, since this isn't where we are validating pass/fail
                                }

                                // dodge http://openradar.appspot.com/21472364
                                if file != "caliper.json" && file != "pass1.json" && file != "vega2.schema.json" {
                                    compareCocoaParsing(contents, msg: file)
                                }


                                if type == "profile" {
                                    let count = 6
                                    print("\nProfiling \((fullPath as NSString).lastPathComponent) \(count) times:")
                                    let str = try NSString(contentsOfFile: fullPath, encoding: NSUTF8StringEncoding) as String
                                    try profileJSON(str, count: count, validate: true, cocoa: false, cf: false)
                                    try profileJSON(str, count: count, validate: false, cocoa: false, cf: false)
                                    try profileJSON(str, count: count, validate: false, cocoa: false, cf: true)
                                    try profileJSON(str, count: count, validate: false, cocoa: true, cf: false)
                                } else if type == "jsonschema" {
                                    let bric = try Bric.parse(contents)

                                    // the format of the tests in https://github.com/json-schema/JSON-Schema-Test-Suite are arrays of objects that contain a "schema" item
                                    guard case let .Arr(items) = bric else {
                                        XCTFail("No top-level array in \(file)")
                                        continue
                                    }
                                    for (_, item) in items.enumerate() {
                                        guard case let .Obj(def) = item else {
                                            XCTFail("Array element was not an object: \(file)")
                                            continue
                                        }
                                        guard case let .Some(schem) = def["schema"] else {
                                            XCTFail("Schema object did not contain a schema object key: \(file)")
                                            continue
                                        }
                                        if schem == schem {

                                        }

//                                        do {
//                                            let schema = try Schema.brac(schem)
//                                            let reschema = try Schema.brac(schema.bric())
//                                            XCTAssertEqual(schema, reschema)
//                                        } catch {
//                                            XCTFail("failed to load element #\(i) of \(file) error=\(error): \(schem.stringify())")
//                                        }
                                    }
                                } else if type == "schemas" {
                                    // try to codegen all the schemas
                                    let _ = try parsePath(fullPath, strict: true)
//                                    let _ = try Schema.brac(bric)
//                                    if false {
//                                        let swift = try schema.generateType()
//                                        print("##### swift for \(file):\n\(swift)")
//                                    }
                                } else {
                                    try parsePath(fullPath, strict: type == "jsonchecker")
                                    if file.hasPrefix("fail") {
                                        if file == "fail1.json" {
                                            // don't fail on the no root string test; the spec doesn't forbit it
                                            // "A JSON payload should be an object or array, not a string."
                                        } else if file == "fail18.json" {
                                            // don't fail on the arbitrary depth limit test; the spec doesn't forbit it
                                            // [[[[[[[[[[[[[[[[[[[["Too deep"]]]]]]]]]]]]]]]]]]]]
                                        } else {
                                            XCTFail("Should have failed test at: \(file)")
                                        }
                                    }
                                }
                            }
                        } catch {
                            if file.hasPrefix("fail") {
                                // should fail
                            } else {
                                XCTFail("Should have passed test at: \(file) error: \(error)")
                                dump(error)
                            }
                        }
                    }
                }
            }
        } catch {
            XCTFail("unexpected error when loading tests: \(error)")
        }
    }



    func testStringReplace() {
        XCTAssertEqual("foo".replace("oo", replacement: "X"), "fX")
        XCTAssertEqual("foo".replace("o", replacement: "X"), "fXX")
        XCTAssertEqual("foo".replace("o", replacement: "XXXX"), "fXXXXXXXX")
        XCTAssertEqual("foo".replace("ooo", replacement: "XXXX"), "foo")
        XCTAssertEqual("123".replace("3", replacement: ""), "12")
        XCTAssertEqual("123".replace("1", replacement: ""), "23")
        XCTAssertEqual("123".replace("2", replacement: ""), "13")
        XCTAssertEqual("abcabcbcabcbcbc".replace("bc", replacement: "XYZ"), "aXYZaXYZXYZaXYZXYZXYZ")
    }

    func testJSONPointers() {
        // http://tools.ietf.org/html/draft-ietf-appsawg-json-pointer-04
        let json: Bric = [
            "foo": ["bar", "baz"],
            "": 0,
            "a/b": 1,
            "c%d": 2,
            "e^f": 3,
            "g|h": 4,
            "i\\j": 5,
            "k\"l": 6,
            " ": 7,
            "m~n": 8
        ]

        // ""         // the whole document
        // "/foo"       ["bar", "baz"]
        // "/foo/0"    "bar"
        // "/"          0
        // "/a~1b"      1
        // "/c%d"       2
        // "/e^f"       3
        // "/g|h"       4
        // "/i\\j"      5
        // "/k\"l"      6
        // "/ "         7
        // "/m~0n"      8

        do {
            do { let x = try json.reference(""); XCTAssertEqual(x, json) }
            do { let x = try json.reference("/foo"); XCTAssertEqual(x, ["bar", "baz"]) }
            do { let x = try json.reference("/foo/0"); XCTAssertEqual(x, "bar") }
            do { let x = try json.reference("/"); XCTAssertEqual(x, 0) }
            do { let x = try json.reference("/a~1b"); XCTAssertEqual(x, 1) }
            do { let x = try json.reference("/c%d"); XCTAssertEqual(x, 2) }
            do { let x = try json.reference("/e^f"); XCTAssertEqual(x, 3) }
            do { let x = try json.reference("/g|h"); XCTAssertEqual(x, 4) }
            do { let x = try json.reference("/i\\j"); XCTAssertEqual(x, 5) }
            do { let x = try json.reference("/k\"l"); XCTAssertEqual(x, 6) }
            do { let x = try json.reference("/ "); XCTAssertEqual(x, 7) }
            do { let x = try json.reference("m~0n"); XCTAssertEqual(x, 8) }

        } catch {
            XCTFail("JSON Pointer error: \(error)")
        }
    }

    func testStreamingParser() {
        do {
            let opts = JSONParser.Options.Strict

            do {
                var events: [JSONParser.Event] = []
                let cb: (JSONParser.Event)->() = { event in events.append(event) }

                let parser = JSONParser(options: opts, delegate: cb)
                func one(c: UnicodeScalar) -> [UnicodeScalar] { return [c] }

                try parser.parse(one("["))
                XCTAssertEqual(events, [.ArrayStart(one("["))])

                try parser.parse(one(" "))
                XCTAssertEqual(events, [.ArrayStart(one("[")), .Whitespace([" "])])

                try parser.parse(one("1"))
                // note no trailing number event, because it doesn't know when it is completed
                XCTAssertEqual(events, [.ArrayStart(one("[")), .Whitespace([" "])]) // , .Number(["1"])])

                try parser.parse(one("\n"))
                XCTAssertEqual(events, [.ArrayStart(one("[")), .Whitespace([" "]), .Number(["1"]), .Whitespace(["\n"])])

                try parser.parse(one("]"), complete: true)
                XCTAssertEqual(events, [.ArrayStart(one("[")), .Whitespace([" "]), .Number(["1"]), .Whitespace(["\n"]), .ArrayEnd(one("]"))])
            }

            // break up the parse into a variety of subsets to test that the streaming parser emits the exact same events
            let strm = Array("{\"object\": 1234.56E2}".unicodeScalars)
            let rangesList: [[Range<Int>]] = [
                Array<Range<Int>>(arrayLiteral: 0..<1, 1..<2, 2..<3, 3..<4, 4..<5, 5..<6, 6..<7, 7..<8, 8..<9, 9..<10, 10..<11, 11..<12, 12..<13, 13..<14, 14..<15, 15..<16, 16..<17, 17..<18, 18..<19, 19..<20, 20..<21),
                Array<Range<Int>>(arrayLiteral: 0..<10, 10..<15, 15..<16, 16..<19, 19..<21),
                Array<Range<Int>>(arrayLiteral: 0..<7, 7..<8, 8..<9, 9..<10, 10..<15, 15..<16, 16..<17, 17..<20, 20..<21),
                Array<Range<Int>>(arrayLiteral: 0..<9, 9..<10, 10..<11, 11..<18, 18..<19, 19..<20, 20..<21),
                Array<Range<Int>>(arrayLiteral: 0..<21),
                ]

            for ranges in rangesList {
                var events: [JSONParser.Event] = []
                let cb: (JSONParser.Event)->() = { event in events.append(event) }

                let parser = JSONParser(options: opts, delegate: cb)

                for range in ranges { try parser.parse(Array(strm[range])) }
                try parser.parse([], complete: true)

                XCTAssertEqual(events, [JSONParser.Event.ObjectStart(["{"]),
                    JSONParser.Event.StringStart(["\""]),
                    JSONParser.Event.StringContent(Array("object".unicodeScalars), []),
                    JSONParser.Event.StringEnd(["\""]),
                    JSONParser.Event.KeyValueSeparator([":"]), JSONParser.Event.Whitespace([" "]),
                    JSONParser.Event.Number(Array("1234.56E2".unicodeScalars)),
                    JSONParser.Event.ObjectEnd(["}"])])

            }

            expectEvents("[[[]]]", [.ArrayStart(["["]), .ArrayStart(["["]), .ArrayStart(["["]), .ArrayEnd(["]"]), .ArrayEnd(["]"]), .ArrayEnd(["]"])])
            expectEvents("[[ ]]", [.ArrayStart(["["]), .ArrayStart(["["]), .Whitespace([" "]), .ArrayEnd(["]"]), .ArrayEnd(["]"])])
//            expectEvents("[{\"x\": 2.2}]", [.ArrayStart, .ObjectStart, .String(["x"], []), .KeyValueSeparator, .Whitespace([" "]), .Number(["2", ".", "2"]), .ObjectEnd, .ArrayEnd])

       } catch {
            XCTFail(String(error))
        }
    }


    func testStreamingBricolage() {
        do {
            let opts = JSONParser.Options.Strict

            do {
                let bric: Bric = [123, 456.789, ["xyz": true], false, [], [nil], nil]
                let json = bric.stringify().unicodeScalars
                var brics: [Bric] = []
                try Bric.bricolageParser(options: opts, delegate: { (b, _) in brics.append(b); return b }).parse(json, complete: true)

                // the expected output: note that redundant values are expected, since every bric generates an event
                let expected: [Bric] = [123, 456.789, "xyz", true, ["xyz": true], false, [], nil, [nil], nil, [123, 456.789, ["xyz": true], false, [], [nil], nil]]

                XCTAssertEqual(brics, expected)
            } catch {
                XCTFail(String(error))
            }

            do {
                var processed: [Bric] = []

                // here we are filtereding all events at leavel 1 so they are not stored in the top-level Bric array
                // this demonstrates using the parser as a streaming Bricolage parser of top-level array elements
                // without the parser needing the retain all of the events themselves
                let parser = Bric.bricolageParser(options: opts, delegate: { (bric, level) in
                    if level == 1 {
                        processed.append(bric)
                        return nil
                    } else {
                        return bric // not level 1: return the bric itself
                    }
                })

                let inputs: Array<Bric> = [ ["a": true], ["b": 123.45], ["c": nil], ["d": "xyz"] ]
                try parser.parse(["["]) // open a top-level array
                XCTAssertEqual([], processed) // no events yet

                for (i, input) in inputs.enumerate() { // parse each of the strings
                    try parser.parse(input.stringify().unicodeScalars)
                    XCTAssertEqual(i + 1, processed.count) // one event per input
                    try parser.parse([","]) // trailing delimiter to continue the array
                }

                // note that we never complete the parse (we end with a trailing comma)
                XCTAssertEqual(processed, inputs)
            } catch {
                XCTFail(String(error))
            }

        }
    }

    /// Assert that the given events are emitted by the parser
    func expectEvents(string: String, _ events: [JSONParser.Event], file: String = __FILE__, line: UInt = __LINE__) {
        do {
            var evts: [JSONParser.Event] = []
            let cb: (JSONParser.Event)->() = { e in evts.append(e) }

            let parser = JSONParser(options: JSONParser.Options.Strict, delegate: cb)
            try parser.parseString(string)
            XCTAssertEqual(evts, events, file: file, line: line)
        } catch {
            XCTFail(String(error), file: file, line: line)
        }
    }

    func testStreamingEncoding() {
        for (expected, input) in [
            (expected: nil as Bric, input: "null"),
            (expected: ["😂": nil] as Bric, input: "{\"😂\": null}"),
            ] {
                // encode the above in a variety of codecs and feed them into a streaming parser to make sure they parse correctly
                let utf16: [UTF16.CodeUnit] = Array(input.utf16)
                let utf8: [UTF8.CodeUnit] = Array(input.utf8)

                // there's no nice "utf32" convenience property on String, so we manually build it up
                var utf32: [UTF32.CodeUnit] = []
                for scalar in input.unicodeScalars {
                    UTF32.encode(scalar, output: { utf32.append($0) })
                }

                // print("utf8: \(utf8)") // 14 elements: [91, 34, 240, 159, 152, 130, 34, 44, 32, 110, 117, 108, 108, 93]
                // print("utf16: \(utf16)") // 12 elements: [91, 34, 55357, 56834, 34, 44, 32, 110, 117, 108, 108, 93]
                // print("utf32: \(utf32)") // 11 elements: [91, 34, 128514, 34, 44, 32, 110, 117, 108, 108, 93]

                do {
                    let utf8out = try parseCodec(UTF8.self, utf8)
                    XCTAssertEqual(utf8out, expected)
                } catch {
                    XCTFail(String(error))
                }

                do {
                    let utf16out = try parseCodec(UTF16.self, utf16)
                    XCTAssertEqual(utf16out, expected)
                } catch {
                    XCTFail(String(error))
                }


                do {
                    let utf32out = try parseCodec(UTF32.self, utf32)
                    XCTAssertEqual(utf32out, expected)
                } catch {
                    XCTFail(String(error))
                }
        }
    }

    func testStreamingDecoding() {
        // U+1F602 (Emoji: "face with tears of joy") in UTF-8 is: 240, 159, 152, 130
        var units: [UTF8.CodeUnit] = [240, 159, 152, 130]

        transcode(UTF8.self, UTF32.self, units.generate(), {
            assert(UnicodeScalar($0) == "\u{1F602}")
            }, stopOnError: true)


        do {
            var codec = UTF8()
            var g = units.generate()
            switch codec.decode(&g) {
            case .EmptyInput: fatalError("No Input")
            case .Error: fatalError("Decoding Error")
            case .Result(let scalar): assert(scalar == "\u{1F602}")
            }

        }

        do {
            var codec = UTF8()

            do {
                var g1 = GeneratorOfOne(units[0])
                let r1 = codec.decode(&g1)
                print("r1: \(r1)") // .Error
            }

            do {
                var g2 = GeneratorOfOne(units[1])
                let r2 = codec.decode(&g2)
                print("r2: \(r2)") // .EmptyInput
            }

            do {
                var g3 = GeneratorOfOne(units[2])
                let r3 = codec.decode(&g3)
                print("r3: \(r3)") // .EmptyInput
            }

            do {
                var g4 = GeneratorOfOne(units[3])
                let r4 = codec.decode(&g4)
                print("r4: \(r4)") // .EmptyInput
            }
        }

    }

    func testSerializationPerformance() {
        do {
            let path: String! = NSBundle(forClass: BricBracTests.self).pathForResource("test/profile/rap.json", ofType: "")!
            let contents = try NSString(contentsOfFile: path, encoding: NSUTF8StringEncoding)
            let bric = try Bric.parse(contents as String)
            let cocoa = try NSJSONSerialization.JSONObjectWithData(contents.dataUsingEncoding(NSUTF8StringEncoding)!, options: NSJSONReadingOptions())

            for _ in 0...10 {
                var strs: [String] = [] // hang onto the strings so we don't include ARC releases in the profile
                var datas: [NSData] = []

                let styles: [Bool?] = [false, true, nil]
                let styleNames = styles.map({ $0 == true ? "recursive" : $0 == false ? "non-recursive" : "cocoa" })
                var times: [NSTimeInterval] = []

                for style in styles {
                    let start = CFAbsoluteTimeGetCurrent()
                    for _ in 0...10 {
                        if let recursive = style {
                            strs.append(bric.stringify(space: 2, recursive: recursive))
                        } else {
                            datas.append(try NSJSONSerialization.dataWithJSONObject(cocoa, options: NSJSONWritingOptions.PrettyPrinted))
                        }
                    }
                    let end = CFAbsoluteTimeGetCurrent()
                    times.append(end-start)
                }
                print("serialization times: \(styleNames) \(times)")
            }
        } catch {
            XCTFail(String(error))
        }
    }

    func testBricDate() {
        let now = NSDate(timeIntervalSince1970: 500000)
        let dict = ["timestamp": now]
        let bric = dict.bric()
        do {
            let brac = try [String:NSDate].brac(bric)
            XCTAssertEqual(dict, brac)
        } catch {
            XCTFail(String(error))
        }
    }

    func testNestedBricDate() {
        typealias X = Dictionary<String, Optional<Optional<Optional<Optional<NSDate>>>>>
        let now = NSDate(timeIntervalSince1970: 500000)
        let dict: X = X(dictionaryLiteral: ("timestamp", now))
        let bric = dict.bric()
        do {
            let brac: X = try X.brac(bric)
            let t1 = dict["timestamp"]!!!!
            let t2 = brac["timestamp"]!!!!
            XCTAssertTrue(t1 == t2)
        } catch {
            XCTFail(String(error))
        }
    }

    func testAutoBricBrac() {
        let template: Bric = ["manufacturer": "audi", "model": "a4", "displ": 1.8, "year": 1999, "cyl": 4, "trans": "auto(l5)", "drv": "f", "cty": 18, "hwy": 29, "fl": "p", "class": "compact"]

        do {
            let audi1 = try Car.brac(template)
            XCTAssertEqual(audi1.manufacturer, "audi")
            XCTAssertEqual(audi1.model, "a4")
        } catch {
            XCTFail(String(error))
        }


        // "1","audi","a4",1.8,1999,4,"auto(l5)","f",18,29,"p","compact"
        let audi2 = Car(manufacturer: "audi", model: "a4", displacement: 1.8, year: 1999, cylinders: .Four, transmissionType: "auto(l5)", drive: .Front, cityMileage: 18, highwayMileage: 29, fuel: .Premium, `class`: .compact)
        let bric = audi2.bric()
        XCTAssertEqual(bric, template)
        do {
            let audi3 = try Car.brac(bric)
            XCTAssertEqual(audi3, audi2)
        } catch {
            XCTFail(String(error))
        }

        do {
            //
            let list: Bric = ["year": 1999, "type": "efficiency", "cars": [template, template]]
            let uniqueList: Bric = ["year": 1999, "type": "efficiency", "cars": [template]]
            let report = try CarReport.brac(list)
            XCTAssertEqual(report.bric(), uniqueList, "re-serialized list should only contain a single unique element")
        } catch {
            XCTFail(String(error))
        }
    }

    /// Generates code for the experimental AutoBric type
    func XXXtestAutobricerMaker() {
        for i in 2...25 {
            let typeList = (1...i).map({ "T\($0)" }).joinWithSeparator(", ")
            let keyList = Array(count: i, repeatedValue: "R").joinWithSeparator(", ")
            let mediatorList = (1...i).map({ "(bricer: (T\($0) -> Bric), bracer: (Bric throws -> T\($0)))" }).joinWithSeparator(", ")


            print("/// Support for AutoBricBrac types with \(i) properties")
            print("public extension AutoBricBrac {")

            print("    /// Returns a pair of functions that will bric and brac this type based on the passes in factory, keys, accessors, and mediators")
            print("    public static func abricbrac<\(typeList), R: RawRepresentable where R.RawValue == String>(factory: (\(typeList)) -> Self)(_ keys: (\(keyList)))(_ mediators: (\(mediatorList)))(_ accessors: Self -> (\(typeList))) -> (bricer: (Self -> Bric), bracer: (Bric throws -> Self)) {")
            print("")
            print("        let bricer: (Self -> Bric) = { value in")
            print("            let vals = accessors(value)")
            print("            return Bric(object: [", terminator: " ")
            for j in 0..<i {
                print("(keys.\(j), mediators.\(j).bricer(vals.\(j)))" + (j == i-1 ? "" : ","), terminator: " ")
            }
            print("])")
            print("        }")
            print("")
            print("        let bracer: (Bric throws -> Self) = { bric in")
            print("            try factory(", terminator: "")
            for j in 0..<i {
                print("mediators.\(j).bracer(bric.bracKey(keys.\(j)))" + (j == i-1 ? "" : ","), terminator: " ")
            }
            print(")")
            print("        }")
            print("")
            print("        return (bricer, bracer)")
            print("    }")
            print("}")
            print("")

        }
    }
}

/// Parses the given stream of elements with the associated codec
func parseCodec<C: UnicodeCodecType, S: SequenceType where S.Generator.Element == C.CodeUnit>(codecType: C.Type, _ seq: S) throws -> Bric {
    var top: Bric = nil
    let parser = Bric.bricolageParser(options: .Strict) { (b, l) in
        if l == 0 { top = b }
        return b
    }

    let success: Bool = transcode(codecType, UTF32.self, seq.generate(), {
        do {
            try parser.parse(CollectionOfOne(UnicodeScalar($0)))
        } catch {
            fatalError("decoding error")
        }
        }, stopOnError: true)

    if success {
    } else {
    }

    return top
}


/// Takes any collection of UnicodeScalars and parses it, returning the exact same collection
func roundTrip<C: RangeReplaceableCollectionType where C.Generator.Element == UnicodeScalar>(src: C) throws -> C {
    var out: C = C.init()
    out.reserveCapacity(src.count)
    try JSONParser(options: .Strict, delegate: { out.appendContentsOf($0.value) }).parse(src, complete: true)
    return out
}

struct Person {
    var name: String
    var male: Bool
    var age: UInt8?
    var children: [String]
}

/// Example of using an enum in a type extension for BricBrac with automatic hashability and equatability
extension Person : BricBrac, Hashable, Equatable {
    enum Keys: String {
        case name, male, age, children
    }

    func bric() -> Bric {
        return Bric(object: [
            (Keys.name, name.bric()),
            (.male, male.bric()),
            (.age, age.bric()),
            (.children, children.bric()),
            ])
    }

    static func brac(bric: Bric) throws -> Person {
        return try Person(
            name: bric.bracKey(Keys.name),
            male: bric.bracKey(Keys.male),
            age: bric.bracKey(Keys.age),
            children: bric.bracKey(Keys.children)
        )
    }
}


enum Executive : BricBrac {
    case Human(Person)
    case Robot(serialNumber: String)

    func bric() -> Bric {
        switch self {
        case .Human(let p): return p.bric()
        case .Robot(let id): return id.bric()
        }
    }

    static func brac(bric: Bric) throws -> Executive {
        switch bric {
        case .Str(let id): return .Robot(serialNumber: id)
        case .Obj(let dict) where dict["name"] != nil: return try .Human(Person.brac(bric))
        default: return try bric.invalidType()
        }
    }
}

enum CorporateStatus : String, BricBrac {
    case `public`, `private`
}

enum CorporateCode : Int, BricBrac {
    case A = 1, B = 2, C = 3, D = 4
}

/// Example of using a class and a tuple in the type itself to define the keys for BricBrac
final class Company : BricBrac {
    private static let keys = (
        name: "name",
        ceo: "ceo",
        status: "status",
        customers: "customers",
        employees: "employees",
        subsidiaries: "subsidiaries")

    var name: String
    var ceo: Executive?
    var status: CorporateStatus
    var customers: ContiguousArray<Person>
    var employees: [Person]
    var subsidiaries: [Company]?


    init(name: String, ceo: Executive?, status: CorporateStatus, customers: ContiguousArray<Person>, employees: [Person], subsidiaries: [Company]? = nil) {
        self.name = name
        self.ceo = ceo
        self.status = status
        self.customers = customers
        self.employees = employees
        self.subsidiaries = subsidiaries
    }

    func bric() -> Bric {
        let keys = Company.keys
        return [
            keys.name: name.bric(),
            keys.ceo: ceo.bric(),
            keys.status: status.bric(),
            keys.customers: customers.bric(),
            keys.employees: employees.bric(),
            keys.subsidiaries: subsidiaries.bric()
        ]
    }

    static func brac(bric: Bric) throws -> Company {
        return try Company(
            name: bric.bracKey(keys.name),
            ceo: bric.bracKey(keys.ceo),
            status: bric.bracKey(keys.status),
            customers: bric.bracKey(keys.customers),
            employees: bric.bracKey(keys.employees),
            subsidiaries: bric.bracKey(keys.subsidiaries))
    }
}

/// http://www.epa.gov/otaq/cert/mpg/mpg-data/readme.txt
struct Car {
    /// manufacturer or division name
    var manufacturer: String
    /// model name
    var model: Optional<String>
    /// displacement in liters
    var displacement: Double
    /// year manufactured
    var year: UInt16
    /// number of engine cylinders
    var cylinders: Cylinders
    /// type of transmission
    var transmissionType: String // TODO: make an enum with an associated type
    /// drive axle type
    var drive: Drive
    /// estimated city mpg (miles/gallon)
    var cityMileage: Int
    /// estimated highway mpg (miles/gallon)
    var highwayMileage: Int
    /// fuel type
    var fuel: Fuel
    /// vehicle class name
    var `class`: Class

    enum Cylinders : Int { case Four = 4, Six = 6, Eight = 8 }
    enum Drive : String { case Front = "f", Rear = "r", Four }
    enum Fuel : String { case Regular = "r", Premium = "p" }
    enum Class : String { case subcompact, compact, midsize, suv, minivan, pickup }
}

extension Car : AutoBricBrac {
    private static let keys = ("manufacturer", "model", "displ", "year", "cyl", "trans", "drv", "cty", "hwy", "fl", "class")
    private static let creator = Car.abricbrac(Car.init)(keys)
    private static let mediator = creator(((abric, abrac), (abric, abrac), (abric, abrac), (abric, abrac), (abric, abrac), (abric, abrac), (abric, abrac), (abric, abrac), (abric, abrac), (abric, abrac), (abric, abrac)))
    static let autobricbrac = mediator({ x in (x.manufacturer, x.model, x.displacement, x.year, x.cylinders, x.transmissionType, x.drive, x.cityMileage, x.highwayMileage, x.fuel, x.`class`) })
}

extension Car.Cylinders : BricBrac { }
extension Car.Drive : BricBrac { }
extension Car.Fuel : BricBrac { }
extension Car.Class : BricBrac { }

struct CarReport {
    var year: UInt
    var type: ReportType
    var cars: Set<Car>

    enum ReportType: String { case efficiency, style, reliability }
}

extension CarReport : AutoBricBrac {
    static let autobricbrac = CarReport.abricbrac(CarReport.init)(("year", "type", "cars"))(((abric, abrac), (abric, abrac), (abric, abrac)))({ x in (x.year, x.type, x.cars) })
}

extension CarReport.ReportType : BricBrac { }

//extension CGPoint : AutoBricBrac {
//    private static let keys = ("x", "y")
//    private static let constructor = CGPoint.abricbrac({ (x: Int, y: Int) in CGPoint(x: x, y: y) })(keys)
//    private static let mediator = constructor(((abric, abrac), (abric, abrac)))
//    public static let autobricbrac = ({ x in (x.x, x.y) })
//}

extension CGPoint : Bricable, Bracable {
    public func bric() -> Bric {
        return ["x": Bric(x.native), "y": Bric(y.native)]
    }

    public static func brac(bric: Bric) throws -> CGPoint {
        return try CGPoint(x: bric.bracKey("x") as CGFloat.NativeType, y: bric.bracKey("y") as CGFloat.NativeType)
    }
}

/// Example of conferring JSON serialization on an existing non-final class
extension NSDate : Bricable, Bracable {
    /// NSDate will be saved by simply storing it as a double with the number of seconds since 1970
    public func bric() -> Bric {
        return Bric(timeIntervalSince1970)
    }

    /// Restore an NSDate from a "time" field
    public static func brac(bric: Bric) throws -> Self {
        return self.init(timeIntervalSince1970: try bric.bracNum())
    }

}
