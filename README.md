swift-itertools
===============

A port of Python's itertools
(https://docs.python.org/3/library/itertools.html) and related things
to Swift.

Differences from Python
=======================

A Python Iterator is a Swift Generator; the only major difference is
that the next method doesn't have double underscores.

A Python Iterable is a Swift Sequence; the only major difference is
that the iter method is called generate (and doesn't have double
underscores).

Unlike Python, where every Iterator must also be an Iterable that
returns self when you ask for an iterator, Swift appears to have no
such constraint. It seems like at least some Generators are written
this way, so there's no reason not to do the same thing here. But it
does affect the usefulness of these functions. In Python, the
itertools functions take any kind of Iterable, which automatically
means they work on all Iterators (consuming them); the Swift
equivalent, taking any kind of Sequence, means not working on some
Generators. Fortunately, since we're only returning Sequences that are
Generators, at least you can chain itertools functions together the
same way as in Python.

The existing stuff in Swift's standard library (map, etc.) seems to
set a precedent that functions should come last whenever possible
(which makes sense, given the quasi-Ruby-style special handling for
closure arguments), and failing that, sequences should come
first. That's not the same as the standard in Python, but it makes
sense to follow the local Swift standards, so we'll do that.

Some functions can't be as flexible as they are in Python (or at least
I can't figure out how to do so...), so they've been split into
separate functions.

Utility functions and types
===========================

`Addable`
    Protocol for types where `T+T->T` makes sense. `Int` and `Float`
    are already registered.

`array(sequence: Sequence)` --> `T[]`
    Turns any `Sequence` of `T` into an `Array` of `T`. If the
    sequence isn't repeatable, it will be consumed. If it's infinite,
    this will of course hang forever.

`negate(T->Bool)` --> `T->Bool`
    Takes a predicate and returns the opposite predicate.

`zipopt(T?, U?)` --> `(T, U)?`
    Given two optional values, returns an optional tuple, nil if
    either value is nil.

Infinite Iterators
==================

`count(start: Int = 0, step: Int = 1)` -->
    `start, start+step, start+step*2, ...`
    Only counts integers, a restriction Python doesn't enforce.

`cycle(sequence: Sequence)` -->
    `s[0], s[1], ..., s[n-1], s[0], s[1], ...`
	Stashes the values, so it works with non-repeatable sequences.
	(Which may not be an issue in Swift; maybe non-repeatble
    Generators generally aren't sequences?)

`repeat(obj: T, times: Int)` -->
    `obj, obj, ...` (`times` copies)
	Does not allow infinite repeat, unlike Python. Also note that
	there seems to be a type `Repeat(count: Int, repeatedValue: T)`
	in the stdlib but undocumented.
	
Iterators terminating on shortest input sequence
================================================
`accumulate(sequence: Sequence, f: (T, T)->T)` -->
    `s[0], f(s[0], s[1]), f(f(s[0], s[1]), s[2]), ...`
	The function does not have a default value, unlike Python.
	See `cumulative_sum` for a version that does.
	
`cumulative_sum(sequence: Sequence of Addable, f: (T, T)->T = { $0+$1 })` -->
    `s[0], s[0]+s[1], s[0]+s[1]+s[2], ...`
	The function defaults to addition, which is why `cumulative_sum`
    only works on `Addable` types. See `accumulate` for a version that
    works on all sequences. (Currently disabled because of compiler crash.)
	
`chain(sequences: Sequence...)` -->
    `s0[0], s0[1], ..., s0[n0-1], s1[0], ..., s1[n1-1], ...`

`chain_sequences(sequences: Sequence of Sequences)` -->
    `s[0][0], s[0][1], ..., s[0][n0-1], s[1][0], ..., s[1][n1-1], ...`
	This is the equivalent of chain.from_iterable in Python.

`compress(data: Sequence, selectors: Sequence of Bool)` -->
    `d[0] if s[0], d[1] if s[1], ...`
	As usual, unlike Python, the selectors here must be actual Bools.
	To compress based on integers, see `compress_nz`.
	
`compress_nz(data: Sequence, selectors: Sequence of Int)` -->
    `d[0] if s[0]!=0, d[1] if s[1]!=0, ...`
	To compress based on Bools, see `compress`.	

`dropwhile(sequence: Sequence, predicate: T->Bool)` -->
    `s[n], s[n+1], ...` (starting when `predicate(s[n-1])` fails)

`filterfalse(sequence: Sequence, predicate: T->Bool)` -->
    `s[0] if !p(s[0]), s[1] if !p(s[1]), ...`

`groupby(sequence: Sequence, key: T->U)` ->
    `(key(s[0]), [s[0], s[1], ...]), (key(s[n]), [s[n], s[n+1], ...]), ...`
	Unlike the Python version, the key function is not optional; see
    `groupby_nokey` to group equal objects without a key function. 
	Also unlike Python, groupby doesn't return sub-iterators, it
    returns arrays. (Not just because it would be a ton of work to
    return sub-Generator objects, but because people often find
    groupby hard to work with in Python...)	
	
`groupby_nokey(sequence: Sequence)` ->
    `(s[0], [s[0], s[1], ...]), (s[n], [s[n], s[n+1], ...]), ...`
	Groups equal values, without a key function. To use a key
    function, see `groupby`.
	
