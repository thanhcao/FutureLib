//
//  SharedCancellationState.swift
//  FutureLib
//
//  Copyright © 2015 Andreas Grosam. All rights reserved.
//

import Dispatch


private enum CancellationState {
    typealias ClosureRegistryType = ClosureRegistry<Bool>

    case pending(ClosureRegistryType)
    case completed(Bool)


    fileprivate init() {
        self = .pending(ClosureRegistryType())
    }


    fileprivate init(completed: Bool) {
        self = self.completed(completed)
    }


    fileprivate var isCompleted: Bool {
        switch self {
        case .completed: return true
        default: return false
        }
    }


    fileprivate var isCancelled: Bool {
        switch self {
        case .completed(let v): return v
        default: return false
        }
    }


    fileprivate mutating func cancel() {
        switch self {
        case .pending(let state):
            self = CancellationState(completed: true)
            state.resume(true)
        case .completed: break
        }
    }


    fileprivate mutating func complete() {
        switch self {
        case .pending(let state):
            self = CancellationState(completed: false)
            state.resume(false)
        case .completed: break
        }
    }


    fileprivate mutating func register(_ f: (Bool)->()) -> Int {
        var result: Int = -1
        switch self {
        case .pending(var cr):
            result = cr.register(f)
            self = .pending(cr)

        case .completed(let cancelled): f(cancelled)
        }
        return result
    }


    /**
     Unregister the closure previously registered with `register`.

     - parameter id: The `id` representing the closure which has been obtained with `onCancel`.
     */
    fileprivate func unregister(_ id: Int) {
        switch self {
        case .pending(var cr):
            cr.unregister(id)
        default: break
        }
    }


}

private let syncQueue = DispatchQueue(label: "cancellation.sync_queue", attributes: [])

internal final class SharedCancellationState {

    fileprivate var value = CancellationState()


    final var isCompleted: Bool {
        var result = false
        syncQueue.sync {
            result = self.value.isCompleted
        }
        return result
    }


    final var isCancelled: Bool {
        var result = false
        syncQueue.sync {
            result = self.value.isCancelled
        }
        return result
    }


    final func cancel() {
        syncQueue.async {
            self.value.cancel()
        }
    }


    final func complete() {
        syncQueue.async {
            self.value.complete()
        }
    }


    /**
     Register a closure which will be called when `self` has been completed.

     - parameter on: An exdcution context where function `f` will be executed.
     - parameter f: The closure which will be executed.
     - returns: An id which represents the registered closure which can be used
     to unregister it again.
     */
    final func register(on executor: ExecutionContext, f: (Bool)->()) -> Int {
        var result = -1
        syncQueue.sync {
            result = self.value.register { cancelled in
                executor.execute {
                    f(cancelled)
                }
            }
        }
        return result
    }


    /**
     Unregister the closure previously registered with `register`.

     - parameter id: The `id` representing the closure which has been obtained with `onCancel`.
     */
    final func unregister(_ id: Int) {
        syncQueue.async {
            self.value.unregister(id)
        }
    }


    final func onCancel(on executor: ExecutionContext,
        cancelable: Cancelable,
        f: (Cancelable)->()) -> Int {
        var result: Int = -1
        syncQueue.sync {
            result = self.value.register { cancelled in
                if cancelled {
                    executor.execute {
                        f(cancelable)
                    }
                }
                self // keep a reference in order to prevent from prematurely
                     // deinitialization
            }
        }
        return result
    }


    final func onCancel(on executor: ExecutionContext, f: ()->()) -> Int {
        var result: Int = -1
        syncQueue.sync {
            result = self.value.register { cancelled in
                if cancelled {
                    executor.execute {
                        f()
                    }
                }
                self // keep a reference in order to prevent from prematurely
                     // deinitialization
            }
        }
        return result
    }



}
