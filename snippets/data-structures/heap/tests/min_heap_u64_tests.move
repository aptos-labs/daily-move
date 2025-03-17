#[test_only]
/// This is a test only module specifically for holding tests, it will not be compiled into a published module
module deploy_addr::min_heap_u64_tests {
    use deploy_addr::min_heap_u64;

    #[test]
    /// Tests various sucessful heap operations
    fun test_heap_creation() {
        let inputs = vector[
            vector[],
            vector[0],
            vector[0, 0],
            vector[0, 1],
            vector[1, 0],
            vector[1, 0, 0],
            vector[1, 1, 0],
            vector[1, 1, 1],
            vector[0, 1, 1],
            vector[0, 0, 1],
            vector[0, 0, 0, 1],
            vector[0, 0, 1, 1],
            vector[0, 1, 1, 1],
            vector[1, 1, 1, 1],
            vector[10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
            vector[5, 1, 2, 4, 2, 99, 0, 1, 1, 234, 525, 123, 2, 21313, 5455, 0, 0, 523]
        ];
        inputs.for_each(|input| {
            let heap = min_heap_u64::from_vec(input);
            let output = min_heap_u64::to_vec(heap);
            is_heap_ordered(&output)
        })
    }

    #[test]
    /// Tests various sucessful heap operations
    fun test_heap_sort() {
        let inputs = vector[
            vector[],
            vector[0],
            vector[0, 0],
            vector[0, 1],
            vector[1, 0],
            vector[1, 0, 0],
            vector[1, 1, 0],
            vector[1, 1, 1],
            vector[0, 1, 1],
            vector[0, 0, 1],
            vector[0, 0, 0, 1],
            vector[0, 0, 1, 1],
            vector[0, 1, 1, 1],
            vector[1, 1, 1, 1],
            vector[10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
            vector[5, 1, 2, 4, 2, 99, 0, 1, 1, 234, 525, 123, 2, 21313, 5455, 0, 0, 523]
        ];
        inputs.for_each(|input| {
            let sorted = min_heap_u64::heap_sort(input);
            is_vec_sorted(&sorted)
        })
    }

    #[test]
    fun heap_e2e_test() {
        let heap = min_heap_u64::new();
        assert!(heap.is_empty());
        heap.insert(2);
        assert!(heap.min() == 2);
        heap.insert(1);
        assert!(heap.min() == 1);
        heap.insert(0);
        assert!(heap.min() == 0);
        heap.insert(0);
        assert!(heap.min() == 0);

        assert!(!heap.is_empty());
        assert!(4 == heap.size());
        assert!(0 == heap.pop());
        assert!(0 == heap.pop());
        assert!(1 == heap.pop());
        assert!(2 == heap.pop());
    }

    #[test]
    #[expected_failure(abort_code = 1, location = min_heap_u64)]
    /// Checks that a left child will fail if out of order
    fun test_pop_empty() {
        min_heap_u64::new().pop();
    }

    #[test]
    #[expected_failure(abort_code = 1, location = min_heap_u64)]
    /// Checks that a left child will fail if out of order
    fun test_min_empty() {
        min_heap_u64::new().min();
    }

    #[test]
    /// Tests the check order function to ensure that in order heaps are correctly followed
    fun test_check_order() {
        let heaps = vector[
            vector[],
            vector[0],
            vector[0, 0],
            vector[0, 1],
            vector[0, 0, 0],
            vector[0, 1, 0],
            vector[0, 0, 1],
            vector[0, 1, 1],
            vector[1, 1, 1],
            vector[1, 1, 1],
        ];
        heaps.for_each(|heap| {
            is_heap_ordered(&heap)
        })
    }

    #[test]
    #[expected_failure(abort_code = 1, location = Self)]
    /// Checks that a left child will fail if out of order
    fun test_check_false() {
        is_heap_ordered(&vector[1, 0])
    }

    #[test]
    #[expected_failure(abort_code = 2, location = Self)]
    /// Checks that a right child will fail if out of order
    fun test_check_false_2() {
        is_heap_ordered(&vector[1, 1, 0])
    }

    /// Helper function to check the order of a heap
    fun is_heap_ordered(heap: &vector<u64>) {
        let length = heap.length();
        for (i in 0..length) {
            let left = 2 * i + 1;
            let right = left + 1;
            let cur = heap[i];

            // Ensure if there are children, that they're greater than the current value
            if (left < length) {
                assert!(cur <= heap[left], 1);
            };
            if (right < length) {
                assert!(cur <= heap[right], 2);
            }
        }
    }


    /// Helper function to check the sorting of a vec
    fun is_vec_sorted(input: &vector<u64>) {
        let length = input.length();
        if (length == 0) { return };

        let previous = input.borrow(0);
        for (i in 1..length) {
            let cur = input.borrow(i);
            assert!(*previous <= *cur, 99);
            previous = cur;
        }
    }
}
