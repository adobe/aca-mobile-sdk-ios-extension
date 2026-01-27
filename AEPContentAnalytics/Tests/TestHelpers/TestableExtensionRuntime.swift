//
// Copyright 2021 Adobe. All rights reserved.
// This file is licensed to you under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License. You may obtain a copy
// of the License at http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software distributed under
// the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
// OF ANY KIND, either express or implied. See the License for the specific language
// governing permissions and limitations under the License.
//
// TEMPORARY: Local copy until aepsdk-testutils-ios is compatible with AEPCore 5.7.0
// Issue: AEPTestUtils 5.0.x has compatibility issues with AEPCore 5.7.0:
//   - Missing Foundation imports in FileManager extension
//   - ExtensionRuntime protocol conformance mismatches
// Source: aepsdk-core-ios/AEPCore/Mocks/PublicTestUtils/TestableExtensionRuntime.swift

import Foundation
@testable import AEPCore

/// Testable implementation for `ExtensionRuntime`
public class TestableExtensionRuntime: ExtensionRuntime {
    private let queue = DispatchQueue(label: "com.adobe.testableextensionruntime.syncqueue")

    public var listeners: [String: EventListener] = [:]
    private var _dispatchedEvents: [Event] = []
    public var createdSharedStates: [[String: Any]?] = []
    public var createdXdmSharedStates: [[String: Any]?] = []
    public var mockedSharedStates: [String: SharedStateResult] = [:]
    public var mockedXdmSharedStates: [String: SharedStateResult] = [:]
    public var receivedEventHistoryRequests: [EventHistoryRequest] = []
    public var receivedEnforceOrder: Bool = false
    public var mockEventHistoryResults: [EventHistoryResult] = []
    public var ignoredEvents = Set<String>()
    public var receivedRecordHistoricalEvent: Event? = nil
    public var recordHistoricalEventCalled = false
    public var recordHistoricalEventResult = true

    public init() {}
    
    /// Helper to set mocked shared state (creates SharedStateResult internally)
    public func setMockedSharedState(extensionName: String, data: [String: Any]?) {
        if let data = data {
            // SharedStateResult is a struct with value and status properties
            // We create it using the internal initializer which is accessible from @testable import
            mockedSharedStates[extensionName] = SharedStateResult(status: .set, value: data)
        } else {
            mockedSharedStates[extensionName] = nil
        }
    }

    // MARK: - ExtensionRuntime methods
    public func unregisterExtension() {}

    public func registerListener(type: String, source: String, listener: @escaping EventListener) {
        listeners["\(type)-\(source)"] = listener
    }

    public func dispatch(event: Event) {
        if shouldIgnore(event) { return }
        queue.async { self._dispatchedEvents += [event] }
    }

    public func createSharedState(data: [String: Any], event _: Event?) {
        createdSharedStates += [data]
    }

    public func createPendingSharedState(event _: Event?) -> SharedStateResolver {
        return { data in
            self.createdSharedStates += [data]
        }
    }

    public func createXDMSharedState(data: [String: Any], event _: Event?) {
        createdXdmSharedStates += [data]
    }

    public func createPendingXDMSharedState(event _: Event?) -> SharedStateResolver {
        return { data in
            self.createdXdmSharedStates += [data]
        }
    }

    public func getSharedState(extensionName: String, event: Event?, barrier: Bool) -> SharedStateResult? {
        let key = event == nil ? "\(extensionName)" : "\(extensionName)-\(event!.id)"
        return mockedSharedStates[key] ?? mockedSharedStates[extensionName]
    }
    
    public func getSharedState(extensionName: String, event: Event?, barrier: Bool, resolution: SharedStateResolution) -> SharedStateResult? {
        let key = event == nil ? "\(extensionName)" : "\(extensionName)-\(event!.id)"
        return mockedSharedStates[key] ?? mockedSharedStates[extensionName]
    }

    public func getXDMSharedState(extensionName: String, event: Event?, barrier: Bool) -> SharedStateResult? {
        let key = event == nil ? "\(extensionName)" : "\(extensionName)-\(event!.id)"
        return mockedXdmSharedStates[key] ?? mockedXdmSharedStates[extensionName]
    }
    
    public func getXDMSharedState(extensionName: String, event: Event?, barrier: Bool, resolution: SharedStateResolution) -> SharedStateResult? {
        let key = event == nil ? "\(extensionName)" : "\(extensionName)-\(event!.id)"
        return mockedXdmSharedStates[key] ?? mockedXdmSharedStates[extensionName]
    }
    
    public func recordHistoricalEvent(_ event: Event, handler: ((Bool) -> Void)?) {
        receivedRecordHistoricalEvent = event
        recordHistoricalEventCalled = true
        handler?(recordHistoricalEventResult)
    }

    public func startEvents() {}

    public func stopEvents() {}

    public func getHistoricalEvents(_ requests: [EventHistoryRequest], enforceOrder: Bool, handler: @escaping ([EventHistoryResult]) -> Void) {
        receivedEventHistoryRequests.append(contentsOf: requests)
        receivedEnforceOrder = enforceOrder
        handler(mockEventHistoryResults)
    }

    // MARK: - Helper methods
    public func ignoreEvent(type: String, source: String) {
        ignoredEvents.insert("\(type)-\(source)")
    }

    public func resetIgnoredEvents() {
        ignoredEvents.removeAll()
    }

    private func shouldIgnore(_ event: Event) -> Bool {
        ignoredEvents.contains("\(event.type)-\(event.source)")
    }

    public func simulateComingEvents(_ events: Event...) {
        for event in events {
            listeners["\(event.type)-\(event.source)"]?(event)
            listeners["\(EventType.wildcard)-\(EventSource.wildcard)"]?(event)
        }
    }

    public func getListener(type: String, source: String) -> EventListener? {
        return listeners["\(type)-\(source)"]
    }

    public func simulateSharedState(for pair: (extensionName: String, event: Event), data: (value: [String: Any]?, status: SharedStateStatus)) {
        mockedSharedStates["\(pair.extensionName)-\(pair.event.id)"] = SharedStateResult(status: data.status, value: data.value)
    }

    public func simulateSharedState(for extensionName: String, data: (value: [String: Any]?, status: SharedStateStatus)) {
        mockedSharedStates["\(extensionName)"] = SharedStateResult(status: data.status, value: data.value)
    }

    public func simulateXDMSharedState(for pair: (extensionName: String, event: Event), data: (value: [String: Any]?, status: SharedStateStatus)) {
        mockedXdmSharedStates["\(pair.extensionName)-\(pair.event.id)"] = SharedStateResult(status: data.status, value: data.value)
    }

    public func simulateXDMSharedState(for extensionName: String, data: (value: [String: Any]?, status: SharedStateStatus)) {
        mockedXdmSharedStates["\(extensionName)"] = SharedStateResult(status: data.status, value: data.value)
    }

    public func resetDispatchedEventAndCreatedSharedStates() {
        dispatchedEvents = []
        createdSharedStates = []
        createdXdmSharedStates = []
    }
    
    public var dispatchedEvents: [Event] {
        get { queue.sync { _dispatchedEvents } }
        set { queue.async { self._dispatchedEvents = newValue } }
    }
}

