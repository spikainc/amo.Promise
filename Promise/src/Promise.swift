//
//  Promise.swift
//  Promise
//
//  Created by amo on 2015/01/11.
//  Copyright (c) 2015年 amo. All rights reserved.
//

import Foundation
import Either

private let default_queue = dispatch_queue_create("promise default queue", nil)

public class Promise<T> {
    typealias Result = Either<T, NSError>
    typealias Continuation = Result -> ()

    private var result: Result?
    private var continuations = [Continuation]()
    
    public let queue: dispatch_queue_t
    
    public init (_ f: (deferred: (resolve: T -> (), reject: NSError -> ())) -> (), _ queue: dispatch_queue_t? = nil) {
        self.queue = queue ?? default_queue
        
        let result = {(result: Result) -> () in
            dispatch_async(self.queue, {
                if self.result != nil {
                    return
                }
                self.result = result
                
                for continuation in self.continuations {
                    continuation(result)
                }
            })
        }
        
        let resolve = { (t: T) -> () in result(Result.bind(t)) }
        let reject = { (e: NSError) -> () in result(Result.bind(e)) }
        
        dispatch_async(self.queue, { f(deferred: (resolve, reject)) })
    }
    
    public class func resolve(t: T, _ queue: dispatch_queue_t? = nil) -> Promise<T> {
        return Promise<T>({deferred in
            deferred.resolve(t)
        }, queue)
    }
    
    public class func reject(e: NSError, _ queue: dispatch_queue_t? = nil) -> Promise<T> {
        return Promise<T>({deferred in
            deferred.reject(e)
        }, queue)
    }
    
    private func applyContinuation(continuation: Result -> ()) {
        dispatch_async(self.queue, { () -> Void in
            if let result = self.result {
                continuation(result)
            } else {
                self.continuations.append(continuation)
            }
        })
    }
    
    private func bind<S>(statement: Result -> Either<S, Promise<S>>) -> Promise<S> {
        return Promise<S>({deferred in
            let f = {(s: S) -> () in
                deferred.resolve(s)
                return
            }
            let g = {(p: Promise<S>) -> () in
                typealias Response = Either<(), Promise<()>>
                p.bind(Either<S, NSError>.coproduct({ s -> Response in
                    deferred.resolve(s)
                    return Response.bind()
                }, { e -> Response in
                    deferred.reject(e)
                    return Response.bind()
                }))
                return
            }
            let e = Either<S, Promise<S>>.coproduct(f, g)
            self.applyContinuation({result in
                e(statement(result))
            })
            return
        }, self.queue)
    }
    
    public func bind<S>(then tStmt: T -> S, catch cStmt: NSError -> S) -> Promise<S> {
        return self.bind(Either<S, Promise<S>>.bindFunc(Result.coproduct(tStmt, g: cStmt)))
    }
    
    public func bind<S>(then tStmt: T -> Promise<S>, catch cStmt: NSError -> Promise<S>) -> Promise<S> {
        return self.bind(Either<S, Promise<S>>.bindFunc(Result.coproduct(tStmt, g: cStmt)))
    }
    
    public func bind<S>(then tStmt: T -> Either<S, Promise<S>>, catch cStmt: NSError -> Either<S, Promise<S>>) -> Promise<S> {
        return self.bind(Result.coproduct(tStmt, cStmt))
    }
    
    // then
    public func then<S>(thenStatement: T -> S) -> Promise<S> {
        return self.then(Either<S, Promise<S>>.bindFunc(thenStatement))
    }
    
    public func then<S>(thenStatement: T -> Promise<S>) -> Promise<S> {
        return self.then(Either<S, Promise<S>>.bindFunc(thenStatement))
    }
    
    public func then<S>(thenStatement: T -> Either<S, Promise<S>>) -> Promise<S> {
        let catchStatement = {(e: NSError) -> Either<S, Promise<S>> in
            Either<S, Promise<S>>.bind(Promise<S>.reject(e, self.queue))
        }
        return self.bind(Result.coproduct(thenStatement, catchStatement))
    }
    
    // catch
    public func catch(catchStatement: NSError -> T) -> Promise<T> {
        return self.catch(Either<T, Promise<T>>.bindFunc(catchStatement))
    }
    
    public func catch(catchStatement: NSError -> Promise<T>) -> Promise<T> {
        return self.catch(Either<T, Promise<T>>.bindFunc(catchStatement))
    }
    
    public func catch(catchStatement: NSError -> Either<T, Promise<T>>) -> Promise<T> {
        let thenStatement = {(t: T) -> Either<T, Promise<T>> in
            Either<T, Promise<T>>.left(t)
        }
        return self.bind(Result.coproduct(thenStatement, catchStatement))
    }
    
    // all
    public class func all(promises: [Promise<T>], _ queue: dispatch_queue_t? = nil) -> Promise<[T]> {
        let q = queue ?? default_queue
        return Promise<[T]>({deferred in
            var counter = promises.count
            var values = [T?](count: promises.count, repeatedValue: nil)
            
            for (i, promise) in enumerate(promises) {
                promise
                    .then {val -> () in
                        dispatch_async(q, { () -> Void in
                            values[i] = val
                            if --counter == 0 {
                                deferred.resolve(values.map { $0! })
                            }
                        })
                    }
                    .catch {e -> () in
                        deferred.reject(e)
                    }
            }
        }, q)
    }
}
