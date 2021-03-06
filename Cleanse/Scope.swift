//
//  _Scope.swift
//  Cleanse
//
//  Created by Mike Lewis on 4/22/16.
//  Copyright © 2016 Square, Inc. All rights reserved.
//

import Foundation

// Type erased version of _Scope

/// Currently there are only two scopes, `_Unscoped` and `Singleton`.
public protocol _Scope {
}

/// This a special scope that means its not scoped
public struct _Unscoped : _Scope {
}

/// This is similar to the javax.inject.Singleton in java
public struct Singleton : _Scope {
}

protocol Finalizable {
    func finalize() throws
}

struct AnonymousFinalizable : Finalizable {
    let finalizeFunc: () throws -> ()
    
    func finalize() throws {
        try self.finalizeFunc()
    }
}


private var weakProviderAssociatedObjectKey = 0

class ScopedProvider {
    private let rawProvider : AnyProvider
    
    private let lock = NSLock()

    private var strongCachedValue: Any?
    private weak var weakCachedValue: AnyObject?
    
    init(rawProvider: AnyProvider) {
        self.rawProvider = rawProvider
    }
    
    var supportsWeak: Bool {
        return rawProvider.instanceProvidesType is AnyClass
    }
    
    /// This retains self
    var wrappedProvider: AnyProvider {
        return rawProvider.dynamicType.makeNew(getter: self.provide)
    }

    private var cachedValue: Any? {
        get {
            if supportsWeak {
                if let weakCachedValue = weakCachedValue {
                    return weakCachedValue
                }
            }
            
            return strongCachedValue
        }
        
        set {
            if supportsWeak {
                weakCachedValue = (newValue as! AnyObject)
                return
            }
            
            strongCachedValue = newValue
        }
    }

    private func provide() -> Any {
        // If we already have it we can avoid locking
        if let cachedValue = cachedValue {
            return cachedValue
        }
        
        return lock.with {
            if let cachedValue = cachedValue {
                return cachedValue
            }
            
            let newValue = rawProvider.getAny()
            
            if supportsWeak {
                let newValue = newValue as! AnyObject
                /// HACK: we want to make these objects retain this so the weak providers don't dealloc
                objc_setAssociatedObject(newValue, &weakProviderAssociatedObjectKey, self, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
            
            self.cachedValue = newValue
            
            return newValue
        }
    }
}