//
//  SwenTests.swift
//  Sixt-iOS
//
//  Created by Dmitry Poznukhov on 11/11/16.
//  Copyright © 2016 e-Sixt GmbH & Co. KG. All rights reserved.
//

import XCTest
@testable import Swen

private struct TestEvent: Event {}

private struct TestStickyEvent: StickyEvent {
    var value = ""
}

class SwenTests: XCTestCase {

    let timeout = 5.0

    func test_SynchronousDispatching_when_Post_Register_on_same_Queue() {
        var dispatched = false
        Swen<TestEvent>.register(self) { _ in
            dispatched = true
        }

        Swen.post(TestEvent())
        Swen<TestEvent>.unregister(self)
        XCTAssertTrue(dispatched)
    }

    func test_RegisterOnMain_PostFromMain_Queue() {
        let exp = expectation(description: "eventReceivedExpectation")
        Swen<TestEvent>.register(self) { _ in
            XCTAssertEqual(OperationQueue.current, OperationQueue.main)
            exp.fulfill()
        }

        Swen.post(TestEvent())

        waitForExpectations(timeout: timeout)
        Swen<TestEvent>.unregister(self)
    }

    func test_RegisterOnMain_PostFromBackground_Queue() {
        let exp = expectation(description: "eventReceivedExpectation")
        let postQueue = OperationQueue()
        Swen<TestEvent>.register(self) { _ in
            XCTAssertEqual(OperationQueue.current, OperationQueue.main)
            exp.fulfill()
        }

        postQueue.addOperation {
            Swen.post(TestEvent())
        }

        waitForExpectations(timeout: timeout)
        Swen<TestEvent>.unregister(self)
    }

    func test_RegisterOnBackground_PostFromMain_Queue() {
        let exp = expectation(description: "eventReceivedExpectation")
        Swen<TestEvent>.registerOnBackground(self) { _ in
            XCTAssertNotEqual(OperationQueue.current, OperationQueue.main)
            exp.fulfill()
        }

        Swen.post(TestEvent())

        waitForExpectations(timeout: timeout)
        Swen<TestEvent>.unregister(self)
    }

    func test_RegisterOnBackground_PostFromBackground_Queue() {
        let exp = expectation(description: "eventReceivedExpectation")
        let postQueue = OperationQueue()
        Swen<TestEvent>.registerOnBackground(self) { _ in
            XCTAssertNotEqual(OperationQueue.current, OperationQueue.main)
            XCTAssertNotEqual(OperationQueue.current, postQueue)
            exp.fulfill()
        }

        postQueue.addOperation {
            Swen.post(TestEvent())
        }

        waitForExpectations(timeout: timeout)
        Swen<TestEvent>.unregister(self)
    }

    func test_RegisterOnCustom_PostFrommain_Queue() {
        let exp = expectation(description: "eventReceivedExpectation")
        let receiveQueue = OperationQueue()
        Swen<TestEvent>.register(self, onQueue: receiveQueue) { _ in
            XCTAssertEqual(OperationQueue.current, receiveQueue)
            exp.fulfill()
        }

        Swen.post(TestEvent())

        waitForExpectations(timeout: timeout)
        Swen<TestEvent>.unregister(self)
    }

    func test_RegisterOnCustom_PostFromBackground_Queue() {
        let exp = expectation(description: "eventReceivedExpectation")
        let receiveQueue = OperationQueue()
        let postQueue = OperationQueue()
        Swen<TestEvent>.register(self, onQueue: receiveQueue) { _ in
            XCTAssertEqual(OperationQueue.current, receiveQueue)
            exp.fulfill()
        }

        postQueue.addOperation {
            Swen.post(TestEvent())
        }

        waitForExpectations(timeout: timeout)
        Swen<TestEvent>.unregister(self)
    }

    func test_GetStickyOnRegisterAfterPost() {
        Swen.post(TestStickyEvent())

        let exp = expectation(description: "StickyEventReceivedExpectation")
        Swen<TestStickyEvent>.register(self) { _ in
            exp.fulfill()
        }

        waitForExpectations(timeout: timeout)
        Swen<TestStickyEvent>.unregister(self)
    }

    func test_GetStickyAfterPost() {
        let sendingEvent = TestStickyEvent(value: "TestEvent")
        Swen.post(sendingEvent)

        let receivedEvent: TestStickyEvent? = Swen.sticky()

        XCTAssertEqual(sendingEvent.value, receivedEvent?.value)
    }

    func test_Receive_After_PostDifferentEvent() {
        let exp = expectation(description: "oldEventReceivedExpectation")
        Swen<TestEvent>.register(self) { _ in
            exp.fulfill()
        }

        Swen.post(TestStickyEvent())
        Swen.post(TestEvent())

        waitForExpectations(timeout: timeout)
        Swen<TestEvent>.unregister(self)
    }

    func test_RegisterPost_InStorage() {
        let storage = SwenStorage()
        let exp = expectation(description: "eventReceivedExpectation")
        Swen<TestEvent>.register(self, in: storage) { _ in
            XCTAssertEqual(OperationQueue.current, OperationQueue.main)
            exp.fulfill()
        }

        Swen.post(TestEvent(), in: storage)

        waitForExpectations(timeout: timeout)
        Swen<TestEvent>.unregister(self, in: storage)
    }

    func test_RegisterPost_InStorage_Overlaping() {
        let storage1 = SwenStorage()
        let storage2 = SwenStorage()
        let exp = expectation(description: "eventReceivedExpectation")
        Swen<TestEvent>.register(self, in: storage1) { _ in
            XCTAssertEqual(OperationQueue.current, OperationQueue.main)
            exp.fulfill()
        }

        Swen<TestEvent>.register(self, in: storage2) { _ in
            XCTFail("event posted in wrong storage")
        }

        Swen<TestEvent>.register(self) { _ in
            XCTFail("event posted in wrong storage")
        }

        Swen.post(TestEvent(), in: storage1)

        waitForExpectations(timeout: timeout)
        Swen<TestEvent>.unregister(self, in: storage1)
        Swen<TestEvent>.unregister(self)
    }

    func test_Unregister() {
        var handlerCalled = false
        Swen<TestEvent>.register(self) { _ in
            handlerCalled = true
        }

        Swen.post(TestEvent())

        XCTAssertTrue(handlerCalled)
        Swen<TestEvent>.unregister(self)

        handlerCalled = false
        Swen.post(TestEvent())
        XCTAssertFalse(handlerCalled)
    }

    func test_DeallocateHandler() {

        var observer: TestObserver? = TestObserver()

        Swen.post(TestEvent())

        XCTAssertTrue(observer!.handlerCalled)
        observer = nil
        Swen.post(TestEvent())
    }

    func testReleaseListeners() {
        Swen.post(TestStickyEvent())

        Swen<TestStickyEvent>.register(self) { _ in }
        weak var listener = Swen<TestStickyEvent>.instance(in: .defaultStorage).listeners.first
        Swen<TestStickyEvent>.unregister(self)

        XCTAssertNil(listener)
    }

    func testReleaseListenersForNonStickyEvent() {
        let registerQueue = OperationQueue()

        Swen<TestEvent>.register(self, onQueue: registerQueue) { _ in }
        weak var listener = Swen<TestEvent>.instance(in: .defaultStorage).listeners.first
        Swen.post(TestEvent())
        Swen<TestEvent>.unregister(self)

        XCTAssertNil(listener)
    }

    func testReleaseListenersForStickyEvent() {
        let registerQueue = OperationQueue()

        Swen<TestStickyEvent>.register(self, onQueue: registerQueue) { _ in }
        weak var listener = Swen<TestStickyEvent>.instance(in: .defaultStorage).listeners.first
        Swen.post(TestStickyEvent())
        Swen<TestStickyEvent>.unregister(self)

        XCTAssertNil(listener)
    }

}

private class TestObserver {
    var handlerCalled = false
    init () {
        Swen<TestEvent>.register(self) { [weak self] _ in
            self?.handlerCalled = true
        }
    }
    deinit {
        Swen<TestEvent>.unregister(self)
    }
}
