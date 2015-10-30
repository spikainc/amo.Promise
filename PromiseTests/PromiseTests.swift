//
//  PromiseTests.swift
//  PromiseTests
//
//  Created by amo on 2015/01/10.
//  Copyright (c) 2015年 amo. All rights reserved.
//

import UIKit
import XCTest
import Promise

extension XCTestCase {
    public func async(timeout: dispatch_time_t = dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), callback: (() -> ()) -> ()) {
        let semaphore = dispatch_semaphore_create(0)
        let done = {() -> () in
            dispatch_semaphore_signal(semaphore)
            return
        }
        
        callback(done)
        
        if dispatch_semaphore_wait(semaphore, timeout) != 0 {
            XCTFail("timed out.")
        }
    }
}

class PromiseTests: XCTestCase {
    var expected: Int!
    var anotherExpected: String!
    var error: NSError!
    var anotherError: NSError!
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        self.expected = 1
        self.anotherExpected = "hoge"
        self.error = NSError(domain: "this is error", code: 1, userInfo: ["hoge": "fuga"])
         self.anotherError = NSError(domain: "this is another error", code: 2, userInfo: ["hoge": "piyo"])
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func test_初期化時に渡した関数内で解決した値をthenで取得できる() {
        self.async { done in
            Promise<Int>({ deferred in
                deferred.resolve(self.expected)
            }).then({ (actual: Int) -> () in
                XCTAssertEqual(self.expected, actual)
                done()
            })
            return
        }
    }
    
    func test_初期化時に渡した関数内で非同期的に解決した値をthenで取得できる() {
        self.async { done in
            let queue = dispatch_queue_create("for test", nil)
            Promise<Int>({ deferred in
                dispatch_async(queue, {
                    deferred.resolve(self.expected)
                })
            }).then({ (actual: Int) -> () in
                XCTAssertEqual(self.expected, actual)
                done()
            })
        }
    }
    
    func test_初期化時に渡した関数内でrejectされた値をfailで捕捉できる() {
        self.async { done in
            Promise<()>({ deferred in
                deferred.reject(self.error)
            }).fail { (actual: NSError) -> () in
                XCTAssertEqual(self.error.domain, actual.domain)
                XCTAssertEqual(self.error.code, actual.code)
                XCTAssertEqual(self.error.userInfo!["hoge"] as! String, actual.userInfo!["hoge"] as! String)
                done()
            }
            return
        }
    }
    
    func test_初期化時に渡した関数内で非同期的にrejectされた値をfailで捕捉できる() {
        self.async { done in
            let queue = dispatch_queue_create("for test", nil)
            Promise<()>({ deferred in
                dispatch_async(queue, {
                    deferred.reject(self.error)
                })
            }).fail { (actual: NSError) -> () in
                XCTAssertEqual(self.error.domain, actual.domain)
                XCTAssertEqual(self.error.code, actual.code)
                XCTAssertEqual(self.error.userInfo!["hoge"] as! String, actual.userInfo!["hoge"] as! String)
                done()
            }
        }
    }
    
    
    // クラスメソッドの resolve と reject
    func test_resolveで渡した値をthenで取得できる() {
        self.async { done in
            Promise<Int>.resolve(self.expected).then({ (actual: Int) -> () in
                XCTAssertEqual(self.expected, actual)
                done()
            })
            return
        }
    }
    
    func test_rejectで渡したerrorをfailで捕捉できる() {
        self.async { done in
            Promise<()>.reject(self.error).fail { (actual: NSError) -> () in
                XCTAssertEqual(self.error.domain, actual.domain)
                XCTAssertEqual(self.error.code, actual.code)
                XCTAssertEqual(self.error.userInfo!["hoge"] as! String, actual.userInfo!["hoge"] as! String)
                done()
            }
            return
        }
    }
    
    
    // then, fail を繋げられる
    func test_thenで返した新しい値を次のthenで取得できる() {
        self.async { done in
            Promise<Int>.resolve(self.expected).then({ (t: Int) -> String in
                return self.anotherExpected
            }).then { (actual: String) -> () in
                XCTAssertEqual(self.anotherExpected, actual)
                done()
            }
            return
        }
    }
    
    func test_thenで返した新しいerrorを次のfailで捕捉できる() {
        self.async { done in
            Promise<Int>.resolve(self.expected).then({ (n: Int) -> Promise<()> in
                return Promise<()>.reject(self.error)
            }).fail { (actual: NSError) -> () in
                XCTAssertEqual(self.error.domain, actual.domain)
                XCTAssertEqual(self.error.code, actual.code)
                XCTAssertEqual(self.error.userInfo!["hoge"] as! String, actual.userInfo!["hoge"] as! String)
                done()
            }
            return
        }
    }
    
    func test_failで返した値を次のthenで取得できる() {
        self.async { done in
            Promise<Int>.reject(self.error).fail({ (e: NSError) -> Int in
                return self.expected
            }).then { (actual: Int) -> () in
                XCTAssertEqual(self.expected, actual)
                done()
            }
            return
        }
    }
    
    func test_failで返した新しいerrorを次のfailで捕捉できる() {
        self.async { done in
            Promise<()>.reject(self.error).fail({ (e: NSError) -> Promise<()> in
                return Promise<()>.reject(self.anotherError)
            }).fail { (actual: NSError) -> () in
                XCTAssertEqual(self.anotherError.domain, actual.domain)
                XCTAssertEqual(self.anotherError.code, actual.code)
                XCTAssertEqual(self.anotherError.userInfo!["hoge"] as! String, actual.userInfo!["hoge"] as! String)
                done()
            }
            return
        }
    }
    
    func test_errorが発生した場合failの前のthenは無視される() {
        self.async { done in
            let semaphore = dispatch_semaphore_create(0)
            var counter = 0
            Promise<Int>({ deferred in
                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
                deferred.reject(self.error)
            }).then({(n: Int) -> () in
                counter++
                return
            }).fail({ (actual: NSError) -> () in
                XCTAssertEqual(counter, 0)
                XCTAssertEqual(self.error.domain, actual.domain)
                XCTAssertEqual(self.error.code, actual.code)
                XCTAssertEqual(self.error.userInfo!["hoge"] as! String, actual.userInfo!["hoge"] as! String)
            }).then({() -> () in
                done()
                return
            })
            dispatch_semaphore_signal(semaphore)
        }
    }
}
