//
//  Promise.swift
//  Promise
//
//  Created by amo on 2015/01/11.
//  Copyright (c) 2015年 amo. All rights reserved.
//

import Foundation
import Either

public class Promise<T> {
    typealias Result = Either<T, NSError>
    typealias Continuation = Result -> ()

    private var result: Result?
    private var continuations = [Continuation]()
    
    private let queue: dispatch_queue_t
    
    public init (_ f: (Result -> ()) -> (), _ queue: dispatch_queue_t? = nil) {
        self.queue = queue ?? dispatch_get_main_queue()
        
        let resolve = {(result: Result) in
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
        
        dispatch_async(queue, { f(resolve) })
    }
    
    public class func resolve(t: T, _ queue: dispatch_queue_t? = nil) -> Promise<T> {
        return Promise<T>({resolve in
            resolve(Result.bind(t))
        }, queue)
    }
    
    public class func reject(e: NSError, _ queue: dispatch_queue_t? = nil) -> Promise<T> {
        return Promise<T>({resolve in
            resolve(Result.bind(e))
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
        return Promise<S>({resolve in
            let f = {(s: S) -> () in
                resolve(Either<S, NSError>.left(s))
                return
            }
            let g = {(p: Promise<S>) -> () in
                p.bind({res -> Either<Void, Promise<Void>> in
                    resolve(res)
                    return Either.bind()
                })
                return
            }
            let e = Either<S, Promise<S>>.coproduct(f, g)
            self.applyContinuation({result in
                e(statement(result))
            })
            return
        }, self.queue)
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
            Either<S, Promise<S>>.right(Promise<S>.reject(e, self.queue))
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
        return Promise<[T]>({resolve in
            var counter = promises.count
            var result = [T?](count: promises.count, repeatedValue: nil)
            
            for (i, promise) in enumerate(promises) {
                promise
                    .then {res -> () in
                        dispatch_async(queue, { () -> Void in
                            result[i] = res
                            if --counter == 0 {
                                resolve(Either<[T], NSError>.bind(result.map { $0! }))
                            }
                        })
                        return
                    }
                    .catch {e -> () in
                        resolve(Either<[T], NSError>.bind(e))
                        return
                    }
            }
        }, queue)
        
    }
}
