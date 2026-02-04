/*
 Copyright 2026 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import Foundation

/// Thread-safe LRU (Least Recently Used) cache with size limit
/// Automatically evicts least recently used items when capacity is reached
class LRUCache<Key: Hashable, Value> {
    
    private class Node {
        let key: Key
        var value: Value
        var prev: Node?
        var next: Node?
        
        init(key: Key, value: Value) {
            self.key = key
            self.value = value
        }
    }
    
    private let capacity: Int
    private var cache: [Key: Node] = [:]
    private var head: Node?
    private var tail: Node?
    private let queue = DispatchQueue(label: "com.adobe.contentanalytics.lrucache", attributes: .concurrent)
    
    /// Initialize with maximum capacity
    /// - Parameter capacity: Maximum number of items to store (must be > 0)
    init(capacity: Int) {
        precondition(capacity > 0, "LRU cache capacity must be greater than 0")
        self.capacity = capacity
    }
    
    /// Get value for key, marking it as recently used
    /// - Parameter key: Key to look up
    /// - Returns: Value if exists, nil otherwise
    /// - Note: Uses barrier flag because moveToHead() mutates the linked list
    func get(_ key: Key) -> Value? {
        return queue.sync(flags: .barrier) {
            guard let node = cache[key] else { return nil }
            moveToHead(node)
            return node.value
        }
    }
    
    func set(_ value: Value, forKey key: Key) {
        queue.sync(flags: .barrier) {
            performSet(value, forKey: key)
        }
    }
    
    func setAsync(_ value: Value, forKey key: Key, completion: (() -> Void)? = nil) {
        queue.async(flags: .barrier) { [weak self] in
            self?.performSet(value, forKey: key)
            completion?()
        }
    }
    
    private func performSet(_ value: Value, forKey key: Key) {
        if let existingNode = self.cache[key] {
            // Update existing node
            existingNode.value = value
            self.moveToHead(existingNode)
        } else {
            // Add new node
            let newNode = Node(key: key, value: value)
            self.cache[key] = newNode
            self.addToHead(newNode)
            
            // Evict LRU if over capacity
            if self.cache.count > self.capacity {
                if let tailNode = self.tail {
                    self.remove(tailNode)
                    self.cache.removeValue(forKey: tailNode.key)
                }
            }
        }
    }
    
    /// Remove value for key
    /// - Parameter key: Key to remove
    func remove(_ key: Key) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self, let node = self.cache[key] else { return }
            self.remove(node)
            self.cache.removeValue(forKey: key)
        }
    }
    
    /// Remove all items from cache
    func removeAll() {
        queue.async(flags: .barrier) { [weak self] in
            self?.cache.removeAll()
            self?.head = nil
            self?.tail = nil
        }
    }
    
    /// Get current number of items in cache
    var count: Int {
        return queue.sync {
            return cache.count
        }
    }
    
    /// Get all keys currently in cache
    var keys: [Key] {
        return queue.sync {
            return Array(cache.keys)
        }
    }
    
    // MARK: - Private Helpers
    
    private func moveToHead(_ node: Node) {
        remove(node)
        addToHead(node)
    }
    
    private func addToHead(_ node: Node) {
        node.prev = nil
        node.next = head
        head?.prev = node
        head = node
        
        if tail == nil {
            tail = node
        }
    }
    
    private func remove(_ node: Node) {
        let prev = node.prev
        let next = node.next
        
        prev?.next = next
        next?.prev = prev
        
        if node === head {
            head = next
        }
        
        if node === tail {
            tail = prev
        }
        
        node.prev = nil
        node.next = nil
    }
    
    // MARK: - Additional Helpers
    
    func values() -> [Value] {
        return queue.sync {
            return Array(cache.values.map { $0.value })
        }
    }
}
