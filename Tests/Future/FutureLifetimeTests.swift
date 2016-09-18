//
//  FutureLifetimeTests.swift
//  FutureTests
//
//  Copyright © 2015 Andreas Grosam. All rights reserved.
//

import XCTest
import FutureLib



class Dummy {
    let _expect: XCTestExpectation
    init(_ expect: XCTestExpectation) {
        _expect = expect
    }
    deinit {
        _expect.fulfill()
    }
}




/// Initialize and configure the Logger
internal var Log: Logger  = {
    var target = ConsoleEventTarget()
    target.writeOptions = .Sync
    return Logger(category: "FutureLibTests", verbosity: Logger.Severity.trace, targets: [target])
}()



class Foo<T> {
    typealias ArrayClosure = ([T])->()
}

class FutureLifetimeTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    
    
    //    // Livetime
    
    func testFutureShouldDeallocateIfThereAreNoObservers() {
        let promise = Promise<Int>()
        weak var weakRef: Future<Int>?
        func t() {
            let future = promise.future
            weakRef = future
        }
        t()
        XCTAssertNil(weakRef)
    }
    
    func testFutureShouldDeallocateIfThereAreNoObservers2() {
        let cr = CancellationRequest()
        let ct = cr.token
        let promise = Promise<Int>()
        let expect1 = self.expectation(description: "cancellation handler should be unregistered")
        
        DispatchQueue.global(priority: 0).async {
            let future = promise.future!
            let d1 = Dummy(expect1)
            future.onSuccess(ct: ct) { i -> () in
                XCTFail("unexpected")
                print(d1)
            }
        }
        
        DispatchQueue.global(priority: 0).asyncAfter(deadline: DispatchTime.now() + Double((Int64)(100 * NSEC_PER_MSEC)) / Double(NSEC_PER_SEC)) {
            cr.cancel()
        }
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testFutureShouldDeallocateIfThereAreNoObservers3() {
        let cr = CancellationRequest()
        let ct = cr.token
        let promise = Promise<Int>()
        let expect1 = self.expectation(description: "cancellation handler should be unregistered")
        let expect2 = self.expectation(description: "cancellation handler should be unregistered")
        
        DispatchQueue.global(priority: 0).async {
            let future = promise.future!
            let d1 = Dummy(expect1)
            let d2 = Dummy(expect2)
            
            future.onSuccess(ct: ct) { i -> () in
                XCTFail("unexpected")
                print(d1)
            }
            future.onSuccess(ct: ct) { i -> () in
                XCTFail("unexpected")
                print(d2)
            }
        }
        DispatchQueue.global(priority: 0).asyncAfter(deadline: DispatchTime.now() + Double((Int64)(10 * NSEC_PER_MSEC)) / Double(NSEC_PER_SEC)) {
            cr.cancel()
        }
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testFutureShouldDeallocateIfThereAreNoObservers4() {
        let cr = CancellationRequest()
        let ct = cr.token
        let promise = Promise<Int>()
        let expect1 = self.expectation(description: "cancellation handler should be unregistered")
        let expect2 = self.expectation(description: "cancellation handler should be unregistered")
        let expect3 = self.expectation(description: "cancellation handler should be unregistered")
        
        DispatchQueue.global(priority: 0).async {
            let future = promise.future!
            let d1 = Dummy(expect1)
            let d2 = Dummy(expect2)
            
            future.onSuccess(ct: ct) { i -> () in
                XCTFail("unexpected")
                print(d1)
            }
            future.onSuccess(ct: ct) { i -> () in
                XCTFail("unexpected")
                print(d2)
            }
            DispatchQueue.global(priority: 0).asyncAfter(deadline: DispatchTime.now() + Double((Int64)(10 * NSEC_PER_MSEC)) / Double(NSEC_PER_SEC)) {
                cr.cancel()
                DispatchQueue.global(priority: 0).asyncAfter(deadline: DispatchTime.now() + Double((Int64)(10 * NSEC_PER_MSEC)) / Double(NSEC_PER_SEC)) {
                    let d3 = Dummy(expect3)
                    future.onSuccess(ct: cr.token) { i -> () in
                        XCTFail("unexpected")
                        print(d3)
                    }
                }
            };
        }
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    
    
    func testFutureShouldNotDeallocateIfThereIsOneObserver() {
        weak var weakRef: Future<Int>?
        let promise = Promise<Int>()
        let sem = DispatchSemaphore(value: 0)
        func t() {
            let future = promise.future!
            future.onSuccess { value -> () in
                sem.signal()
            }
            weakRef = future
        }
        t()
        XCTAssertNotNil(weakRef)
        promise.fulfill(0)
        sem.wait(timeout: DispatchTime.distantFuture)
        let future = weakRef
        XCTAssertNil(future)
    }
    
    func testFutureShouldCompleteWithBrokenPromiseIfPromiseDeallocatesPrematurely() {
        let expect = self.expectation(description: "future should be fulfilled")
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            let promise = Promise<String>()
            promise.future!.onFailure { error in
                if case PromiseError.brokenPromise = error , error is PromiseError {
                } else {
                    XCTFail("Invalid kind of error: \(String(reflecting: error)))")
                }
                expect.fulfill()
            }
            let delay = DispatchTime.now() + Double(Int64(0.05 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).asyncAfter(deadline: delay) {
                promise
            }
        }
        waitForExpectations(timeout: 0.4, handler: nil)
    }
    
    
    
    func testPromiseChainShouldNotDeallocatePrematurely() {
        let expect = self.expectation(description: "future should be fulfilled")
        let delay = DispatchTime.now() + Double(Int64(0.2 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            let promise = Promise<String>()
            let future = promise.future!
            future.map { str -> String in
                usleep(1000)
                return "1"
            }
            .map { str in
                "2"
            }
            .onSuccess { str in
                expect.fulfill()
            }
            
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).asyncAfter(deadline: delay) {
                promise.fulfill("OK")
            }
        }
        waitForExpectations(timeout: 1, handler: nil)
    }
    

}
