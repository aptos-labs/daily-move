#[test_only]
module example::min_heap_u64_tests {
    use std::vector;
    use example::min_heap_u64;

    #[test]
    fun smoke_test() {
        let heap = min_heap_u64::new();

        // Assert without error code (Move 2)
        assert!(heap.is_empty());
        // Receiver syntax (Move 2)
        heap.insert(1);
        heap.insert(0);

        assert!(2 == heap.size());
        assert!(!heap.is_empty());
        assert!(0 == heap.min());
        assert!(!heap.is_empty());
        assert!(0 == heap.pop());
        assert!(!heap.is_empty());
        assert!(1 == heap.size());

        assert!(1 == heap.min());
        assert!(!heap.is_empty());
        assert!(1 == heap.pop());
        assert!(heap.is_empty());
        assert!(0 == heap.size());
    }

    #[test]
    fun to_vec_test() {
        let heap = min_heap_u64::new();

        // Assert without error code (Move 2)
        assert!(heap.is_empty());
        heap.insert(1);
        heap.insert(0);
        heap.insert(3);
        let vec = heap.to_vec();
        assert!(vector::length(&vec) == 3);

        // Vector index notation (Move 2)
        assert!(vec[0] == 0);
        assert!(vec[1] == 3);
        assert!(vec[2] == 1);
    }
}
