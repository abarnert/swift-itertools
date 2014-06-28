swift-itertools
===============

A port of Python's [`itertools`][itertools] and related things to Swift.

    [itertools]: https://docs.python.org/3/library/itertools.html

Background
==========

Developers in functional languages have long known the benefits of
writing programs as a chain of list transformations, but lazy
languages like Haskell have shown that this can be taken much
farther. Python's `Iterator` protocol (along with related features)
captures most of the benefit of lazy lists. Over the years, much of
the relevant part of the Haskell standard prelude has been ported to
Python (some as part of the standard library, mostly in the
`itertools` module, and some in third-party modules like Erik Rose's
[`more-itertools`][more-itertools], and Python developers have found
new uses for this functionality (e.g., see David Beazley's
[Generator Tricks for Systems Programmers][gentricks]). Many newer
languages, like Scala and Clojure, have taken advantage of the
experience of Haskell and Python to provide similar functionality.

    [more-itertools]: https://github.com/erikrose/more-itertools
	[gentricks]: http://www.dabeaz.com/generators-uk/

Swift's `Generator` protocol is almost identical to Python's
`Iterator` protocol, allowing for the same style of
programming. However, its standard library provides only the most
basic functions for processing them--`map` and `filter` and not much
else. This library is an attempt to rectify that problem by porting
useful functions from Python, Scala, Clojure, and Haskell to Swift,
starting with most of Python's `itertools` module.

To understand some of these functions, it may help to think at a
higher level of abstraction, of monads rather than specifically
sequences, optional values, etc.. However, experience with Python and
Scala developers have shown that this is a tough hurdle for many
people, so I've kept things on the concrete level; there are no
functions to lift a function to any monad, etc., just functions that
deal with sequences, optionals, etc.

The resulting library should probably be called `gentools` or
`seqtools` (since what Python calls `Iterator` and `Iterable`, Swift
calls `Generator` and `Sequence`), but since `itertools` is such a
well-known (and searchable) name, it seemed more appropriate.

Writing this library has also given me a good opportunity to learn
Swift. See the blog [Stupid Swift Ideas][] for some of what I've
discovered along the way.

    [Stupid Swift Ideas]: http://stupidswiftideas.blogspot.com

Static types and homogenous sequences
=====================================

In keeping with Swift's nature as a traditional static-typed language,
its collections are homogenous, so `Sequence` and `Generator` are
meant to be implemented by homogenous collections, which are generic
types parameterized on the element type. (The protocols themselves are
_not_ generic; instead, they use associated types, which can be bound
to the parameters in implementing types. See [Generics][] in the Swift
Language Guide for details.) While heterogeneous
collections can be implemented either Java-style (by parameterizing on
`any` or `AnyObject`) or ObjC-style (by bridging a class like
`NSArray` that implements the `NSFastEnumeration` protocol) and
casting back and forth, general-purpose functions like these should
work on generic, homogenous sequences.

    [Generics]: https://developer.apple.com/library/prerelease/ios/documentation/swift/conceptual/swift_programming_language/Generics.html

Because Swift attempts to be a stricter static language than Java or
C#, more on the lines with C++ (or even Haskell), some familiarity
with the C++ standard-library algorithms derived from [STL][] may be
useful. However, it's worth noting that many of the techniques and
concepts from that library don't seem to be portable to Swift. For
example, many C++ functions that a sequence (or, rather, a pair of
`iterator`s--which doesn't mean the same thing as in either Python or
Swift--but that can be ignored, as a Swift `Generator` is equivalent
to a C++ input iterator that knows its own `end`) of type `T`, and a
function that operates on objects of any type `U` for which `T` is
convertible to `U`. There doesn't seem to be any way to define such a
constraint in Swift, so the corresponding functions require a function
on type `T` itself.

    [STL]: http://en.wikipedia.org/wiki/Standard_Template_Library
	
Similarly, while C++ makes it possible to define a function over a
variable number of heterogeneous parameters (by using template
parameter packs), Scala does not; variadic arguments must all be of
the same type.

Differences from Python
=======================

A Python `Iterator` is a Swift `Generator`; the only major difference
is that the `next` method doesn't have double underscores.

A Python `Iterable` is a Swift `Sequence`; the only major difference
is that the iter method is called `generate` (and doesn't have double
underscores).

Unlike Python, where every `Iterator` must also be an `Iterable` that
returns `self` when you ask for an iterator, Swift appears to have no
such constraint. It seems like at least some `Generator` types are
written this way, so there's no reason not to do the same thing
here. But it does affect the usefulness of these functions. In Python,
the `itertools` functions take any kind of `Iterable`, which
automatically means they work on any `Iterator` (consuming it); the
Swift equivalent, taking any kind of `Sequence`, means not working on
some `Generator`s. Fortunately, since we're only returning `Sequence`s
that are `Generator`s, at least you can chain `itertools` functions
together the same way as in Python.

The existing stuff in Swift's standard library (`map`, etc.) seems to
set a precedent that functions should come last whenever possible
(which makes sense, given the quasi-Ruby-style special handling for
closure arguments), and failing that, sequences should come
first. That's not the same as the standard in Python, but it makes
sense to follow the local Swift standards, so we'll do that.

In Python, variadic parameters can be followed by optional parameters,
making those optional parameters keyword-only. Swift allows for
variadic, optional, and keyword-only parameters, but doesn't allow any
way to combine them all in a single function.

Some functions can't be as flexible as they are in Python (or at least
I can't figure out how to do so...), sometimes because of the
homogenous sequence issue, but sometimes because of limitations of the
language. Such cases have been split into separate functions.

Utility functions and types
===========================

`Addable`
    Protocol for types where `T+T->T` makes sense. `Int` and `Float`
    are already registered.

`array(sequence: Sequence)` --> `T[]`
    Turns any `Sequence` of `T` into an `Array` of `T`. If the
    sequence isn't repeatable, it will be consumed. If it's infinite,
    this will of course hang forever.

`defaultify(value: T?, defvalue: T)` --> `value! or defvalue`
    Supplies a default value for an optional. (May not be necessary
	with future compilers, but for now it's needed to work around a
	compiler crash from the obvious way to do this concisely inline.)

`negate(T->Bool)` --> `T->Bool`
    Takes a predicate and returns the opposite predicate.

`zipopt(T?, U?)` --> `(T, U)?`
    Given two optional values, returns an optional tuple, nil if
    either value is nil.

Folding functions
=================

While Swift does have a builtin `reduce(sequence, start, function)`,
just running `reduce([1, 2, 3, 4], 0, {$0+$1})` takes about 8 seconds
on my laptop. Also, neither function nor start can be defaulted, which
means we really need four separate functions to handle all of the
cases. (For a more general `reduce` that includes a `transform`
function as well, we'd need 8, but the three-arg `reduce` plus `map`
should make that unnecessary.) So:

`sum1(sequence: Sequence<T>)` --> 
    `s[0] + s[1] + ...`
	It is an error to call this on an empty sequence.

`sum(sequence: Sequence<T>, start: T)` --> 
    `start + s[0] + s[1] + ...`

`fold1(sequence: Sequence<T>, combine: (T, T)->T` -->
    `combine(combine(...(s[0], s[1]), s[2]), ...)`
	It is an error to call this on an empty sequence.

`fold(sequence: Sequence<T>, start: T, combine: (T, T)->T` -->
    `combine(combine(...(start, s[0]), s[1]), ...)`

Infinite Iterators
==================

`counter(start: Int = 0, step: Int = 1)` -->
    `start, start+step, start+step*2, ...`
	Named `counter` to avoid collision with the builtin `count`.
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

`groupby(sequence: Sequence, key: T->U)` -->
    `(key(s[0]), [s[0], s[1], ...]), (key(s[n]), [s[n], s[n+1], ...]), ...`
	Unlike the Python version, the key function is not optional; see
    `groupby_nokey` to group equal objects without a key function. 
	Also unlike Python, groupby doesn't return sub-iterators, it
    returns arrays. (Not just because it would be a ton of work to
    return sub-Generator objects, but because people often find
    groupby hard to work with in Python...)	
	
`groupby_nokey(sequence: Sequence)` -->
    `(s[0], [s[0], s[1], ...]), (s[n], [s[n], s[n+1], ...]), ...`
	Groups equal values, without a key function. To use a key
    function, see `groupby`.
	
`islice(sequence: Sequence, start=0, stop=nil, step=1)` -->
    `s[start], s[start+step], ..., s[start+n*step]`
    Unlike the Python version, you can't call this with a single
	positional argument as `stop`, but then that's a weird design in
    Python anyway. Use keyword arguments.
	
`starmap(sequence: Sequence of tuples, f)` -->
    `f(*s[0]), f(*s[1]), ...`
    Does not exist, because (a) tuples aren't sequences,
    (b) there doesn't seem to be any way to convert from even a homogenous
    sequence to a tuple or vice-versa, and (c) even if you could, there
    doesn't seem to be any way to call a function given its arguments as
    a tuple.

`tee(sequence: Sequence, n: Int)` -->
    `[s0, s1, ..., sn-1]`
	This should tee a single (possibly non-repeatable) Sequence into n
    separate copies, all of which contain all of the elements of the
    original. Unfortunately, it seems to be impossible to implement
    without a compiler crash.
	
`zip(s0: Sequence of T0, s1: sequence of T1)` -->
    `(s0[0], s1[0]), (s0[1], s1[1]), ...`
	Unlike the Python version, this only handles exactly two
    sequences, because there doesn't seem to be any way to accept
    variadic arguments of different Sequence types, or to build a
    tuple with a dynamically-specified number of elements.

`zip_longest(s0: Sequence of T0?, s1: sequence of T1?)` -->
    `(s0[0], s1[0]), (s0[1], s1[1]), ..., (nil, s1[n]), ...`
	Unlike the Python version, this only handles exactly two sequences
    (like `zip`). It also requires both sequences to be of optional
    values, and fills missing values with `nil`. See also `zip_fill`.
	
`zip_fill(s0: Sequence of T0, s1: sequence of T1, f0: T0, f1: T1)` -->
    `(s0[0], s1[0]), (s0[1], s1[1]), ..., (f0, s1[n]), ...`
	Unlike the Python version, this only handles exactly two sequences
    (like `zip`). Also unlike the Python version, it requires two
    separate fill values. See also `zip_longest`.

Combinatoric generators
=======================

`product(s0: Sequence of T, s1: Sequence of T, ...)` -->
    `(s0[0], s1[0]), (s0[0], s0[1]), ..., (s0[1], s1[0]), ...`
	Unlike Python's `product`, this cannot be used for heterogeneous
	lists of sequences (see `product2`), or for a single sequence with
    a `repeat` parameter (see `self_product`).

`product2(s0: Sequence of T0, s1: Sequence of T1)` -->
    `(s0[0], s1[0]), (s0[0], s0[1]), ..., (s0[1], s1[0]), ...`
	Unlike Python's `product`, this does not take an arbitrary number
    of arguments, it takes exactly two. For a single sequence and a
    `repeat` value, see `self_product`.

`self_product(s: Sequence of T, repeat: Int)` -->
    `(s[0], s[0]), (s[0], s[1]), ..., (s[1], s[0]), ...`
	This is equivalent to `product(s, repeat)` in Python.
	
`permutations`, `combinations`, `combinations_with_replacement` later

Recipes
=======

`take(s: Sequence of T, n: Int)` -->
    `[s[0], s[1], ..., s[n]]`

`tabulate(function: Int->T)` -->
    `function(0), function(1), ...`
	Unlike the Python version, this doesn't take an optional start
    value `n`, because we need to put `function` last to preserve the
    usual trailing-closure style. See `tabulate_n`.

`tabulate_n(n: Int, function: Int->T)` -->
    `function(n), function(n+1), ...`

`consume(sequence: Sequence, n: Int?)` -->
    `nil`
	Note that when called on an actual `Sequence` that creates new
	`Generator`s on each call, rather than one that wraps a
    `Generator` and returns `self`, this will have no visible effect,
	and that seems to be much more common with Swift's stdlib than
    Python's.
	
`nth(sequence: Sequence, n: Int)` -->
    `s[n] or nil`
	Unlike the Python version, this does not take an optional default
	value (because that would change the type from T? to T). See
	`nth_default`.
	
`nth_default(sequence: Sequence, n: Int, defvalue: T)` -->
    `s[n] or defvalue`
