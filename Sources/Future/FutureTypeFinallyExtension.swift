//
//  FutureTypeFinallyExtension.swift
//  FutureLib
//
//  Copyright © 2015 Andreas Grosam. All rights reserved.
//


// MARK: - finally

extension FutureType {

    public final func finally(
        _ ec: ExecutionContext = GCDAsyncExecutionContext(),
        _ ct: CancellationTokenType = CancellationTokenNone(),
        f: (ResultType) -> ()) {
        onComplete(ec: ec, ct: ct, f: f)
    }


    
    public final func finally<U>(
        _ ec: ExecutionContext = GCDAsyncExecutionContext(),
        _ ct: CancellationTokenType = CancellationTokenNone(),
        f: @escaping (ResultType) -> U)
        -> Future<U> {
        let returnedFuture = Future<U>()
        onComplete(ec: ec, ct: ct) { [weak returnedFuture] result in
            // Caution: the mapping function must be called even when the returned
            // future has been deinitialized prematurely!
            let v = f(result)
            returnedFuture?.complete(Try(v))
        }
        return returnedFuture
    }


    
    public final func finally<U>(
        _ ec: ExecutionContext = GCDAsyncExecutionContext(),
        _ ct: CancellationTokenType = CancellationTokenNone(),
        f: @escaping (ResultType) throws -> U)
        -> Future<U> {
        let returnedFuture = Future<U>()
        onComplete(ec: ec, ct: ct) { [weak returnedFuture] result in
            // Caution: the mapping function must be called even when the returned
            // future has been deinitialized prematurely!
            do {
                let v = try f(result)
                returnedFuture?.complete(Try<U>(v))
            } catch let error {
                returnedFuture?.complete(Try<U>(error: error))
            }
        }
        return returnedFuture
    }


    
    public final func finally<U>(
        _ ec: ExecutionContext = GCDAsyncExecutionContext(),
        _ ct: CancellationTokenType = CancellationTokenNone(),
        f: @escaping (ResultType) throws -> Future<U>)
        -> Future<U> {
        let returnedFuture = Future<U>()
        onComplete(ec: SynchronousCurrent(), ct: ct) { [weak returnedFuture] result -> () in
            // Caution: the mapping function must be called even when the returned
            // future has been deinitialized prematurely!
            ec.schedule({ return try f(result) }) { future in
                returnedFuture?.completeWith(future)
            }
        }
        return returnedFuture
    }


}
