/// Heap
///
/// This gives an example of a min heap https://en.wikipedia.org/wiki/Heap_(data_structure)
///
/// A max heap can be handled similarly by changing the comparisons before swapping
module deploy_addr::min_heap {
    use std::vector;

    /// A MinHeap of u64
    ///
    /// Can be used for a priority queue, or for sorting a vector
    struct MinHeap has store, drop {
        inner: vector<u64>
    }

    /// In-place sorts a vector
    ///
    /// Runtime complexity: O(nlog(n))
    /// Extra space: O(1)
    public fun heap_sort(self: &mut vector<u64>) {
        let size = vector::length(self);

        // Heapify from bottom of heap to top
        let root = size / 2;
        while (root > 0) {
            heapify(self, size, root - 1);
            root = root - 1;
        };
    }

    /// Creates an empty heap
    public fun new(): MinHeap {
        MinHeap { inner: vector[] }
    }

    /// Creates a heap from a vector
    ///
    /// Sorts the heap prior to parsing, to ensure it's correctly sorted
    public fun from_vec(vec: vector<u64>): MinHeap {
        heap_sort(&mut vec);

        MinHeap { inner: vec }
    }

    /// Converts the heap to a vector
    public fun to_vec(heap: MinHeap): vector<u64> {
        let MinHeap { inner } = heap;
        inner
    }

    /// Inserts into the heap sorted
    public fun insert(self: &mut MinHeap, value: u64) {
        vector::insert(&mut self.inner, 0, value);
        heapify_heap(self, 0)
    }

    /// Inserts into the heap sorted
    public fun pop(self: &mut MinHeap): u64 {
        let ret = vector::swap_remove(&mut self.inner, 0);
        heapify_heap(self, 0);
        ret
    }

    /// Gets the minimum of the heap (top)
    public fun min(self: &MinHeap): u64 {
        *vector::borrow(&self.inner, 0)
    }

    /// Gets the size of the vector
    public fun size(self: &MinHeap): u64 {
        vector::length(&self.inner)
    }

    /// Returns true if the heap is empty
    public fun is_empty(self: &MinHeap): bool {
        size(self) == 0
    }

    /// Convenience function to heapify just the heap
    inline fun heapify_heap(heap: &mut MinHeap, root: u64) {
        let size = size(heap);
        heapify(&mut heap.inner, size, root)
    }

    /// Take the nodes below the index node, and convert them into a heap
    ///
    /// This happens by checking the root against both children, and swapping the smallest to the root
    fun heapify(array: &mut vector<u64>, size: u64, root: u64) {
        // Base case, ensure that it doesn't crash if there's nothing left
        if (size == 0 || root >= size) { return };

        // Initialize smallest as the current root
        let smallest = root;
        let smallest_value = *vector::borrow(array, smallest);

        // Check two children
        let left = 2 * root + 1;
        let right = left + 1;

        // If left child is smaller than root, make it the smallest
        if (left < size) {
            // Note, this is a little different than usual for readability, and to only borrow once
            // We borrow here and save it so we can replace the smallest value
            let left_value = *vector::borrow(array, left);
            if (left_value < smallest_value) {
                smallest = left;
                smallest_value = left_value;
            };
        } ;

        // If right child is smaller than root and left, make it the smallest
        if (right < size) {
            let right_value = *vector::borrow(array, right);
            if (right_value < smallest_value) {
                smallest = right;
            };
        } ;


        // Swap smallest if it isn't the root
        if (smallest != root) {
            vector::swap(array, smallest, root);

            // Recursively heapify subtrees
            heapify(array, size, smallest);
        };
    }
}
