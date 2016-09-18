//
//  Timer.swift
//  FutureLib
//
//  Copyright © 2015 Andreas Grosam. All rights reserved.
//

import Dispatch

/**
 Implements a cancelable timer with precise timing.
*/
open class Timer {

    public typealias TimerHandler = (Timer) -> ()
    public typealias TimeInterval = Double


    fileprivate let _timer: DispatchSource
    fileprivate let _delay: Int64
    fileprivate let _interval: UInt64
    fileprivate let _leeway: UInt64
    fileprivate var _cancelId: Int = -1
    fileprivate let _cancellationToken: CancellationTokenType


    /**
     Initializes a cancelable, one-shot timer in suspended state.

     Setting a tolerance for a timer allows it to fire later than the scheduled fire
     date, improving the ability of the system to optimize for increased power savings
     and responsiveness. The timer may fire at any time between its scheduled fire date
     and the scheduled fire date plus the tolerance. The timer will not fire before the
     scheduled fire date. The default value is zero, which means no additional tolerance
     is applied.

     As the user of the timer, you will have the best idea of what an appropriate tolerance
     for a timer may be. A general rule of thumb, though, is to set the tolerance to at
     least 10% of the interval, for a repeating timer. Even a small amount of tolerance
     will have a significant positive impact on the power usage of your application.
     The system may put a maximum value of the tolerance.

     - parameter delay: The delay in seconds after the timer will fire
     - parameter tolerance: A tolerance in seconds the fire data can deviate. Must be
     positive.
     - parameter cancellationToken: The cancallation token
     - parameter executionContext:  The execution on which to execute the block.
     - parameter f:  The closure to submit.
     - return: An initialized Timer object.
    */
    public init(delay: TimeInterval, tolerance: TimeInterval,
        cancellationToken: CancellationTokenType = CancellationTokenNone(),
        on ec: ExecutionContext = GCDAsyncExecutionContext(),
        f: @escaping TimerHandler) {
        _delay = Int64((delay * Double(NSEC_PER_SEC)) + 0.5)
        _interval = DispatchTime.distantFuture
        _leeway = UInt64((tolerance * Double(NSEC_PER_SEC)) + 0.5)
        _timer = DispatchSource.makeTimerSource(flags: tolerance > 0 ? 0 : DispatchSource.TimerFlags.strict, queue: DISPATCH_TARGET_QUEUE_DEFAULT) /*Migrator FIXME: Use DispatchSourceTimer to avoid the cast*/ as! DispatchSource
        _cancellationToken = cancellationToken
        _cancelId = cancellationToken.onCancel(on: GCDAsyncExecutionContext()) {
            self._timer.cancel()
        }
        _timer.setEventHandler {
            self._timer.cancel() // one shot timer
            ec.execute {
                f(self)
            }
        }
    }


    /**
     Initializes a cancelable, periodic timer in suspended state.

     Setting a tolerance for a timer allows it to fire later than the scheduled fire
     date, improving the ability of the system to optimize for increased power savings
     and responsiveness. The timer may fire at any time between its scheduled fire date
     and the scheduled fire date plus the tolerance. The timer will not fire before the
     scheduled fire date. The default value is zero, which means no additional tolerance
     is applied.

     As the user of the timer, you will have the best idea of what an appropriate tolerance
     for a timer may be. A general rule of thumb, though, is to set the tolerance to at
     least 10% of the interval, for a repeating timer. Even a small amount of tolerance
     will have a significant positive impact on the power usage of your application.
     The system may put a maximum value of the tolerance.

     - parameter delay: The delay in seconds after the timer will fire
     - parameter interval: The interval in seconds after the timer will fire
     - parameter tolerance: A tolerance in seconds the fire data can deviate. Must be
     positive.
     - parameter cancellationToken: The cancallation token
     - parameter ec:  The execution on which to execute the block.
     - parameter f:  The closure to submit.
     - return: An initialized Timer object.
     */
    public init(delay: TimeInterval, interval: TimeInterval, tolerance: TimeInterval,
        cancellationToken: CancellationTokenType = CancellationTokenNone(),
        ec: ExecutionContext = GCDAsyncExecutionContext(),
        f: @escaping TimerHandler) {
        _delay = Int64((delay * Double(NSEC_PER_SEC)) + 0.5)
        _interval = UInt64((interval * Double(NSEC_PER_SEC)) + 0.5)
        _leeway = UInt64((tolerance * Double(NSEC_PER_SEC)) + 0.5)
        _timer = DispatchSource.makeTimerSource(flags: tolerance > 0 ? 0 : DispatchSource.TimerFlags.strict, queue: DISPATCH_TARGET_QUEUE_DEFAULT) /*Migrator FIXME: Use DispatchSourceTimer to avoid the cast*/ as! DispatchSource
        _cancellationToken = cancellationToken
        _cancelId = cancellationToken.onCancel(on: GCDAsyncExecutionContext()) {
            self._timer.cancel()
        }
        _timer.setEventHandler {
            ec.execute {
                f(self)
            }
        }
    }


    deinit {
        cancel()
    }



    /**
     Starts the timer.

     The timer fires once after the specified delay plus the specified tolerance.
    */
    public final func resume() {
        let time = DispatchTime.now() + Double(_delay) / Double(NSEC_PER_SEC)
        _timer.setTimer(start: time, interval: _interval, leeway: _leeway)
        _timer.resume()
    }



    /**
     Returns `True` if the timer has not yet been fired and if it is not cancelled.
    */
    public final var isValid: Bool {
        return 0 == _timer.isCancelled
    }

    /**
     Cancels the timer. This method cancels the timer regardless of the state
     of the cancellation token.
    */
    public final func cancel() {
        _timer.cancel()
        _cancellationToken.unregister(_cancelId)
    }

}
