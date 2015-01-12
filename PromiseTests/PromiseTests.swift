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
    public func async(callback: (() -> ()) -> (), timeout: dispatch_time_t = dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC))) {
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
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func test_初期化時に渡した関数内で解決した値をthenで取得できる() {
        self.async { done in
            let expected = 1
            Promise<Int>({ deferred in
                deferred.resolve(expected)
            }).then({ (actual: Int) -> () in
                XCTAssertEqual(expected, actual)
                done()
            })
        }
    }
    
    func test_初期化時に渡した関数内で非同期的に解決した値をthenで取得できる() {
        self.async { done in
            let expected = 1
            let queue = dispatch_queue_create("for test", nil)
            Promise<Int>({ deferred in
                dispatch_async(queue, {
                    deferred.resolve(expected)
                })
            }).then({ (actual: Int) -> () in
                XCTAssertEqual(expected, actual)
                done()
            })
        }
    }
    
    func test_初期化時に渡した関数内でrejectされた値をcatchで捕捉できる() {
        self.async { done in
            let error = NSError(domain: "this is error", code: 1, userInfo: ["hoge": "fuga"])
            Promise<Void>({ deferred in
                deferred.reject(error)
            }).catch { (actual: NSError) -> () in
                XCTAssertEqual(error.domain, actual.domain)
                XCTAssertEqual(error.code, actual.code)
                XCTAssertEqual(error.userInfo!["hoge"] as String, actual.userInfo!["hoge"] as String)
                done()
            }
        }
    }
    
    func test_初期化時に渡した関数内で非同期的にrejectされた値をcatchで捕捉できる() {
        self.async { done in
            let error = NSError(domain: "this is error", code: 1, userInfo: ["hoge": "fuga"])
            let queue = dispatch_queue_create("for test", nil)
            Promise<()>({ deferred in
                dispatch_async(queue, {
                    deferred.reject(error)
                })
            }).catch { (actual: NSError) -> () in
                XCTAssertEqual(error.domain, actual.domain)
                XCTAssertEqual(error.code, actual.code)
                XCTAssertEqual(error.userInfo!["hoge"] as String, actual.userInfo!["hoge"] as String)
                done()
                return
            }
        }
    }
    
    
}
