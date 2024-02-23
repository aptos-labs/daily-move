#[test_only]
/// This is a test only module specifically for holding tests, it will not be compiled into a published module
module deploy_addr::min_heap_tests {
    use std::vector;
    use deploy_addr::min_heap::{Self, heap_sort, from_vec};

    #[test]
    /// Tests various sucessful heap sort operations
    fun test_sort() {
        let heaps = vector[
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
            vector[5, 1, 2, 4, 2, 99, 0, 1, 1, 234, 525, 123, 2, 21313, 5455, 0, 0, 523]
        ];
        vector::for_each(heaps, |heap| {
            heap_sort(&mut heap);
            check_order(&heap)
        })
    }

    #[test]
    fun heap_e2e_test() {
        let heap = min_heap::new();
        assert!(min_heap::is_empty(&heap), 1);
        min_heap::insert(&mut heap, 2);
        assert!(min_heap::min(&heap) == 2, 1);
        min_heap::insert(&mut heap, 1);
        assert!(min_heap::min(&heap) == 1, 1);
        min_heap::insert(&mut heap, 0);
        assert!(min_heap::min(&heap) == 0, 1);
        min_heap::insert(&mut heap, 0);
        assert!(min_heap::min(&heap) == 0, 1);

        assert!(!min_heap::is_empty(&heap), 1);
        assert!(4 == min_heap::size(&heap), 1);
        assert!(0 == min_heap::pop(&mut heap), 2);
        assert!(0 == min_heap::pop(&mut heap), 2);
        assert!(1 == min_heap::pop(&mut heap), 2);
        assert!(2 == min_heap::pop(&mut heap), 2);
    }

    #[test]
    fun heap_sort_e2e_test() {
        let vec = vector[2, 3, 4, 5, 1, 0];
        let heap = from_vec(vec);

        assert!(!min_heap::is_empty(&heap), 1);

        let new_vec = min_heap::to_vec(heap);
        check_order(&new_vec);
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
        vector::for_each(heaps, |heap| {
            check_order(&heap)
        })
    }

    #[test]
    #[expected_failure(abort_code = 1, location = Self)]
    /// Checks that a left child will fail if out of order
    fun test_check_false() {
        check_order(&vector[1, 0])
    }

    #[test]
    #[expected_failure(abort_code = 2, location = Self)]
    /// Checks that a right child will fail if out of order
    fun test_check_false_2() {
        check_order(&vector[1, 1, 0])
    }

    /// Helper function to check the order of a heap
    inline fun check_order(heap: &vector<u64>) {
        let length = vector::length(heap);
        for (i in 0..length) {
            let left = 2 * i + 1;
            let right = left + 1;
            let cur = *vector::borrow(heap, i);

            // Ensure if there are children, that they're greater than the current value
            if (left < length) {
                let left_val = *vector::borrow(heap, left);
                assert!(cur <= left_val, 1);
            };
            if (right < length) {
                let right_val = *vector::borrow(heap, right);
                assert!(cur <= right_val, 2);
            }
        }
    }
}
