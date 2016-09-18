//
//  schedule_after.swift
//  FutureLib
//
//  Copyright © 2015 Andreas Grosam. All rights reserved.
//

import Dispatch


public typealias TimeInterval = Double


/**
 An accurate timer for use in unit tests.
 */
private final class AccurateTimer {
    
    fileprivate typealias TimerHandler = () -> ()
    fileprivate typealias TimeInterval = Double
    
    
    fileprivate final let _timer: DispatchSource
    fileprivate final let _delay: Int64
    fileprivate final let _interval: UInt64
    fileprivate final let _leeway: UInt64
    
    fileprivate init(delay: TimeInterval, tolerance: TimeInterval = 0.0,
                 on ec: DispatchQueue = DispatchQueue.global(qos: DispatchQoS.QoSClass.userInteractive),
                     f: @escaping TimerHandler) {
        _delay = Int64((delay * Double(NSEC_PER_SEC)) + 0.5)
        _interval = DispatchTime.distantFuture
        _leeway = UInt64((tolerance * Double(NSEC_PER_SEC)) + 0.5)
        _timer = DispatchSource.makeTimerSource(flags: tolerance > 0 ? 0 : DispatchSource.TimerFlags.strict, queue: DISPATCH_TARGET_QUEUE_DEFAULT) /*Migrator FIXME: Use DispatchSourceTimer to avoid the cast*/ as! DispatchSource
        _timer.setEventHandler {
            self._timer.cancel() // one shot timer
            ec.async(execute: f)
        }
    }
    
    deinit {
        cancel()
    }
    
    
    
    /**
     Starts the timer.
     
     The timer fires once after the specified delay plus the specified tolerance.
     */
    fileprivate final func resume() {
        let time = DispatchTime.now() + Double(_delay) / Double(NSEC_PER_SEC)
        _timer.setTimer(start: time, interval: _interval, leeway: _leeway)
        _timer.resume()
    }
    
    
    
    /**
     Returns `True` if the timer has not yet been fired and if it is not cancelled.
     */
    fileprivate final var isValid: Bool {
        return 0 == _timer.isCancelled
    }
    
    /**
     Cancels the timer.
     */
    fileprivate final func cancel() {
        _timer.cancel()
    }
    
}

/**
 Submits the block on the specifie queue and executed it after the specified delay.
 The delay is as accurate as possible.
 */
public func schedule_after(_ delay: TimeInterval, queue: DispatchQueue = DispatchQueue.global(qos: DispatchQoS.QoSClass.default), f: @escaping () -> ()) {
    let d = delay * Double(NSEC_PER_SEC) * 1.0e-9
    AccurateTimer(delay: d, on: queue, f: f).resume()
}
