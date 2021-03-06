//
//  PropertyInjectionTests.swift
//  Cleanse
//
//  Created by Mike Lewis on 4/26/16.
//  Copyright © 2016 Square, Inc. All rights reserved.
//

import Foundation

import Cleanse
import XCTest

class PropertyInjectionTests: XCTestCase {
    
    struct ATag : Tag { typealias Element = String }
    struct BTag : Tag { typealias Element = String }
    struct CTag : Tag { typealias Element = String }
    struct DTag : Tag { typealias Element = String }

    struct CrazyStructTime {
        let contents: String
    }
    
    class AClass : NSObject {
        var a: String!
    }
    
    class BClass : AClass {
        var b: String!
        var crazyStruct: CrazyStructTime!
        
        func injectProperties(superInjector superInjector: PropertyInjector<AClass>, b: TaggedProvider<BTag>, crazyStruct: CrazyStructTime) {
            superInjector.injectProperties(into: self)
            self.b = b.get()
            self.crazyStruct = crazyStruct
        }
    }
    
    class CClass : BClass {
        var c: TaggedProvider<CTag>!
    }
    
    class DClass : CClass {
        var d: TaggedProvider<DTag>!
    }
    
    
    struct PropertyInjectionModule : Module {
        func configure<B : Binder>(binder binder: B) {
            binder
                .bind()
                .tagged(with:  BTag.self)
                .to(value: "BBBB")
            
            binder
                .bind()
                .tagged(with:  ATag.self)
                .to(value: "AAAAA")
            
            binder
                .bind()
                .tagged(with:  CTag.self)
                .to(value: "CCCCC")
            
            binder
                .bind()
                .to(value: CrazyStructTime(contents: "Fun contents"))
            
            binder
                .bindPropertyInjectionOf(AClass.self)
                .to {
                    $0.a = ($1 as TaggedProvider<ATag>).get()
            }
            
            binder
                .bindPropertyInjectionOf(BClass.self)
                // We generate arities of (Element) -> (arg1, ..., argN) -> () as arguments for to since these are the result of referring to the static method
                .to {
                    $0.injectProperties(superInjector: $1, b: $2, crazyStruct: $3)
            }
            
            
            binder
                .bindPropertyInjectionOf(CClass.self)
                // We also can take to as (Element, arg1, ..., argN). This is convenient for helper methdos or for closures
                .to(injector: self.injectPropertiesIntoC)
            
            
            binder
                .bindPropertyInjectionOf(PropertyInjectionTests.self)
                .to(injector: PropertyInjectionTests.injectProperties)
        }
        
        func injectPropertiesIntoC(target target: CClass, superInjector: PropertyInjector<BClass>, cString: TaggedProvider<CTag>) {
            superInjector.injectProperties(into: target)
            target.a = "I overrode you"
            target.c = cString
        }
    }
    
    func injectProperties(
        propAInjector: PropertyInjector<AClass>,
        propBInjector: PropertyInjector<BClass>,
        propCInjector: PropertyInjector<CClass>
        ) {
        self.propAInjector = propAInjector
        self.propBInjector = propBInjector
        self.propCInjector = propCInjector
    }
    
    var propAInjector: PropertyInjector<AClass>!
    var propBInjector: PropertyInjector<BClass>!
    var propCInjector: PropertyInjector<CClass>!
    
    func testPropertyInject() {
        try! PropertyInjectionModule()
            .asComponent(rootObjectType: PropertyInjector<PropertyInjectionTests>.self)
            .build()
            .injectProperties(into: self)
        
        let a = AClass()
        let b = BClass()
        let c = CClass()
        
        propAInjector.injectProperties(into: a)
        propBInjector.injectProperties(into: b)
        propCInjector.injectProperties(into: c)
        
        XCTAssertEqual(a.a, "AAAAA")
        XCTAssertEqual(b.a, "AAAAA")
        XCTAssertEqual(c.a, "I overrode you")
        
        XCTAssertEqual(b.b, "BBBB")
        XCTAssertEqual(c.b, "BBBB")
    }
}
