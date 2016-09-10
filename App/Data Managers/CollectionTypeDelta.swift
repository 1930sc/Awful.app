//  CollectionTypeDelta.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

extension Collection where Index: Hashable, Iterator.Element: Equatable {
    
    /**
    Returns the difference between `self` and another collection, expressed as a series of deletions, insertions, and moves.
    
    The returned `Delta` is particularly useful for updating a `UICollectionView` or `UITableView`.
    */
    func delta(_ other: Self) -> Delta<Index> {
        var unchanged: Set<Index> = []
        do {
            var i = startIndex
            while i != endIndex && i != other.endIndex {
                defer { i = index(after: i) }
                
                if self[i] == other[i] {
                    unchanged.insert(i)
                }
            }
        }
        
        var insertions: [Index] = []
        var moves: [(from: Index, to: Index)] = []
        do {
            var i = other.startIndex
            while i != other.endIndex {
                defer { i = index(after: i) }
                
                if unchanged.contains(i) { continue }
                
                let otherValue = other[i]
                if let oldIndex = index(of: otherValue) {
                    moves.append((from: oldIndex, to: i))
                } else {
                    insertions.append(i)
                }
            }
        }
        
        var deletions: [Index] = []
        do {
            var i = startIndex
            while i != endIndex {
                defer { i = index(after: i) }
                
                if unchanged.contains(i) { continue }
                
                let value = self[i]
                if !other.contains(value) {
                    deletions.append(i)
                }
            }
        }
        
        return Delta(deletions: deletions, insertions: insertions, moves: moves)
    }
}

/// See documentation for `CollectionType.delta` for usage suggestions.
struct Delta<Index> {
    let deletions: [Index]
    let insertions: [Index]
    let moves: [(from: Index, to: Index)]
    
    /// `true` if and only if the compared collections were identical.
    var isEmpty: Bool {
        return deletions.isEmpty && insertions.isEmpty && moves.isEmpty
    }
    
    // Private initializer suggests this struct is not generally useful except as returned by `CollectionType.delta()`.
    fileprivate init(deletions: [Index], insertions: [Index], moves: [(from: Index, to: Index)]) {
        self.deletions = deletions
        self.insertions = insertions
        self.moves = moves
    }
}
