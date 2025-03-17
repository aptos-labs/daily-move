/// Heap
///
/// This gives an example of a min heap https://en.wikipedia.org/wiki/Heap_(data_structure)
///
/// A max heap can be handled similarly by changing the comparisons before swapping
module deploy_addr::min_heap_u64 {
    spec module {
        pragma verify = true;
    }

    use std::option::{Self, Option};

    /// Heap is empty
    const E_EMPTY: u64 = 1;

    /// A MinHeap of u64
    ///
    /// Can be used for a priority queue, or for sorting a vector
    struct MinHeap has store, drop {
        inner: vector<u64>
    }

    /// Sorts a vector
    ///
    /// Runtime complexity: O(nlog(n))
    /// Extra space: O(n)
    public fun heap_sort(vec: vector<u64>): vector<u64> {
        let heap = from_vec(vec);
        let ret = vector[];
        let length = heap.size();
        for (i in 0..length) {
            ret.push_back(heap.pop());
        };

        ret
    }

    /// In place makes the array a heap
    /// Runtime complexity: O(nlog(n))
    /// Extra space: O(1)
    fun heapify_all(vec: &mut vector<u64>) {
        let size = vec.length();

        // Heapify from bottom of heap to top
        let root = size / 2;
        while (root > 0) {
            heapify(vec, size, root - 1);
            root -= 1;
        };
    }

    /// Creates an empty heap
    public fun new(): MinHeap {
        MinHeap { inner: vector[] }
    }

    spec new(): MinHeap {
        ensures result.is_empty();
    }

    /// Creates a heap from a vector
    ///
    /// Sorts the heap prior to parsing, to ensure it's correctly sorted
    public fun from_vec(vec: vector<u64>): MinHeap {
        heapify_all(&mut vec);

        MinHeap { inner: vec }
    }

    /// Converts the heap to a vector
    public fun to_vec(self: MinHeap): vector<u64> {
        let MinHeap { inner } = self;
        inner
    }
    spec to_vec(self: MinHeap): vector<u64> {
        ensures result == self.inner;
    }

    /// Inserts into the heap sorted
    public fun insert(self: &mut MinHeap, value: u64) {
        self.inner.insert(0, value);
        heapify_heap(self, 0)
    }

    /// Inserts into the heap sorted
    public fun pop(self: &mut MinHeap): u64 {
        assert!(!self.is_empty(), E_EMPTY);
        let ret = self.inner.swap_remove(0);
        heapify_heap(self, 0);
        ret
    }

    /// Gets the minimum of the heap (top)
    public fun min(self: &MinHeap): u64 {
        assert!(!self.is_empty(), E_EMPTY);
        *self.inner.borrow(0)
    }
    spec min(self: &MinHeap): u64 {
        requires len(self.inner) > 0;
        aborts_if self.is_empty();
        aborts_with E_EMPTY;
    }

    /// Gets the size of the vector
    public fun size(self: &MinHeap): u64 {
        self.inner.length()
    }

    spec size(self: &MinHeap): u64 {
        ensures result == len(self.inner);
    }

    /// Returns true if the heap is empty
    public fun is_empty(self: &MinHeap): bool {
        self.size() == 0
    }

    spec is_empty(self: &MinHeap): bool {
        ensures result == (self.size() == 0);
    }

    /// Convenience function to heapify just the heap
    inline fun heapify_heap(heap: &mut MinHeap, root: u64) {
        let size = heap.size();
        heapify(&mut heap.inner, size, root)
    }

    /// Take the nodes below the index node, and convert them into a heap
    ///
    /// This happens by checking the root against both children, and swapping the smallest to the root
    fun heapify(array: &mut vector<u64>, size: u64, root: u64) {
        // Iteratively find the smallest from the top to the bottom of the heap
        let current_root = root;
        while (current_root < size) {
            let maybe_smallest = heapify_inner(array, size, current_root);
            if (maybe_smallest.is_none()) { break };

            current_root = maybe_smallest.destroy_some();
        }
    }

    /// A self contained piece of heapify to allow specifications directly on it
    /// for gas purposes, it would be better to inline, but we can't add specs directly to inline
    fun heapify_inner(array: &mut vector<u64>, size: u64, root: u64): Option<u64> {
        // Initialize smallest as the current root
        let smallest = root;
        let smallest_value = *array.borrow(smallest);

        // Check two children
        let left = left(root);
        let right = right(root);

        // If left child is smaller than root, make it the smallest
        if (left < size) {
            // Note, this is a little different than usual for readability, and to only borrow once
            // We borrow here and save it so we can replace the smallest value
            let left_value = *array.borrow(left);
            if (left_value < smallest_value) {
                smallest = left;
                smallest_value = left_value;
            };
        } ;

        // If right child is smaller than root and left, make it the smallest
        if (right < size) {
            let right_value = *array.borrow(right);
            if (right_value < smallest_value) {
                smallest = right;
            };
        };

        // Swap smallest if it isn't the root
        if (smallest != root) {
            array.swap(smallest, root);
            option::some(smallest)
        } else {
            option::none()
        }
    }

    spec heapify_inner(array: &mut vector<u64>, size: u64, root: u64): Option<u64> {
        requires size > 0;
        // Ensure that the left and right nodes below on the tree are sorted at the end
        ensures left_sorted(array, size, root) && right_sorted(array, size, root);
    }

    spec fun left_sorted(array: vector<u64>, size: u64, root: u64): bool {
        left(root) >= size || array[root] <= array[left(root)]
    }

    spec fun right_sorted(array: vector<u64>, size: u64, root: u64): bool {
        right(root) >= size || array[root] <= array[right(root)]
    }

    inline fun left(i: u64): u64 {
        i * 2 + 1
    }

    inline fun right(i: u64): u64 {
        i * 2 + 2
    }
}
