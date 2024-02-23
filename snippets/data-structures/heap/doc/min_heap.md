
<a id="0x12345_min_heap"></a>

# Module `0x12345::min_heap`

Heap

This gives an example of a min heap https://en.wikipedia.org/wiki/Heap_(data_structure)

A max heap can be handled similarly by changing the comparisons before swapping


-  [Struct `MinHeap`](#0x12345_min_heap_MinHeap)
-  [Function `heap_sort`](#0x12345_min_heap_heap_sort)
-  [Function `new`](#0x12345_min_heap_new)
-  [Function `from_vec`](#0x12345_min_heap_from_vec)
-  [Function `to_vec`](#0x12345_min_heap_to_vec)
-  [Function `insert`](#0x12345_min_heap_insert)
-  [Function `pop`](#0x12345_min_heap_pop)
-  [Function `min`](#0x12345_min_heap_min)
-  [Function `size`](#0x12345_min_heap_size)
-  [Function `is_empty`](#0x12345_min_heap_is_empty)


<pre><code><b>use</b> <a href="">0x1::vector</a>;
</code></pre>



<a id="0x12345_min_heap_MinHeap"></a>

## Struct `MinHeap`

A MinHeap of u64

Can be used for a priority queue, or for sorting a vector


<pre><code><b>struct</b> <a href="min_heap.md#0x12345_min_heap_MinHeap">MinHeap</a> <b>has</b> drop, store
</code></pre>



<a id="0x12345_min_heap_heap_sort"></a>

## Function `heap_sort`

In-place sorts a vector

Runtime complexity: O(nlog(n))
Extra space: O(1)


<pre><code><b>public</b> <b>fun</b> <a href="min_heap.md#0x12345_min_heap_heap_sort">heap_sort</a>(self: &<b>mut</b> <a href="">vector</a>&lt;u64&gt;)
</code></pre>



<a id="0x12345_min_heap_new"></a>

## Function `new`

Creates an empty heap


<pre><code><b>public</b> <b>fun</b> <a href="min_heap.md#0x12345_min_heap_new">new</a>(): <a href="min_heap.md#0x12345_min_heap_MinHeap">min_heap::MinHeap</a>
</code></pre>



<a id="0x12345_min_heap_from_vec"></a>

## Function `from_vec`

Creates a heap from a vector

Sorts the heap prior to parsing, to ensure it's correctly sorted


<pre><code><b>public</b> <b>fun</b> <a href="min_heap.md#0x12345_min_heap_from_vec">from_vec</a>(vec: <a href="">vector</a>&lt;u64&gt;): <a href="min_heap.md#0x12345_min_heap_MinHeap">min_heap::MinHeap</a>
</code></pre>



<a id="0x12345_min_heap_to_vec"></a>

## Function `to_vec`

Converts the heap to a vector


<pre><code><b>public</b> <b>fun</b> <a href="min_heap.md#0x12345_min_heap_to_vec">to_vec</a>(heap: <a href="min_heap.md#0x12345_min_heap_MinHeap">min_heap::MinHeap</a>): <a href="">vector</a>&lt;u64&gt;
</code></pre>



<a id="0x12345_min_heap_insert"></a>

## Function `insert`

Inserts into the heap sorted


<pre><code><b>public</b> <b>fun</b> <a href="min_heap.md#0x12345_min_heap_insert">insert</a>(self: &<b>mut</b> <a href="min_heap.md#0x12345_min_heap_MinHeap">min_heap::MinHeap</a>, value: u64)
</code></pre>



<a id="0x12345_min_heap_pop"></a>

## Function `pop`

Inserts into the heap sorted


<pre><code><b>public</b> <b>fun</b> <a href="min_heap.md#0x12345_min_heap_pop">pop</a>(self: &<b>mut</b> <a href="min_heap.md#0x12345_min_heap_MinHeap">min_heap::MinHeap</a>): u64
</code></pre>



<a id="0x12345_min_heap_min"></a>

## Function `min`

Gets the minimum of the heap (top)


<pre><code><b>public</b> <b>fun</b> <b>min</b>(self: &<a href="min_heap.md#0x12345_min_heap_MinHeap">min_heap::MinHeap</a>): u64
</code></pre>



<a id="0x12345_min_heap_size"></a>

## Function `size`

Gets the size of the vector


<pre><code><b>public</b> <b>fun</b> <a href="min_heap.md#0x12345_min_heap_size">size</a>(self: &<a href="min_heap.md#0x12345_min_heap_MinHeap">min_heap::MinHeap</a>): u64
</code></pre>



<a id="0x12345_min_heap_is_empty"></a>

## Function `is_empty`

Returns true if the heap is empty


<pre><code><b>public</b> <b>fun</b> <a href="min_heap.md#0x12345_min_heap_is_empty">is_empty</a>(self: &<a href="min_heap.md#0x12345_min_heap_MinHeap">min_heap::MinHeap</a>): bool
</code></pre>
