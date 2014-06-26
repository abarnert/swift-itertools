protocol Addable {
    func + (lhs: Self, rhs: Self) -> Self
}
extension Int: Addable {}
extension Float: Addable {}

func array<S: Sequence, T where T == S.GeneratorType.Element>(sequence: S) -> T[] {
    var t = T[]()
    for value in sequence { t.append(value) }
    return t
}

func negate<T>(f: T->Bool) -> T->Bool {
    return { !f($0) }
}

func zipopt<T, U>(t: T?, u: U?) -> (T, U)? {
    if let tt: T = t {
        if let uu: U = u {
            return (tt, uu)
        }
    }
    return nil
}

struct Count: Sequence, Generator {
    var start: Int
    var step: Int
    init(start: Int = 0, step: Int = 1) {
        self.start = start
        self.step = step
    }
    func generate() -> Count {
        return self
    }
    mutating func next() -> Int? {
        let val = start
        start += step
        return val
    }
}

func count(start: Int = 0, step: Int = 1) -> Count { 
    return Count(start: start, step: step)
}

// I'm not sure this is actually needed. Is a Sequence supposed to
// be repeatedly iterable?
struct Cycle<S: Sequence, T where T == S.GeneratorType.Element>
        : Sequence, Generator {
    var generator: S.GeneratorType
    var stash = T[]()
    var index = -1
    init(sequence: S) {
        self.generator = sequence.generate()
    }
    func generate() -> Cycle<S, T> {
        return self
    }
    mutating func next() -> T? {
        if index == -1 {
            if let val = generator.next() { 
                stash.append(val)
                return val
            }
        }
        index = (index + 1) % stash.count
        return stash[index]
    }
}

func cycle<S: Sequence, T where T == S.GeneratorType.Element>
        (sequence: S) -> Cycle<S, T> {
    return Cycle(sequence: sequence)
}

/* Even though it's not in the docs, it's apparently already in the 
   stdlib, except that the arguments are reversed, and it doesn't handle 
   infinite repeat... call it something different?
struct Repeat<T>: Sequence, Generator {
    var obj: T
    var times: Int
    init(obj: T, times: Int = -1) {
        self.obj = obj
        self.times = times
    }
    func generate() -> Repeat<T> {
        return self
    }
    mutating func next() -> T? {
        return times-- == 0 ? nil : obj
    }
}
*/
func repeat<T>(obj: T, times: Int = -1) -> Repeat<T> { 
    return Repeat(count: times, repeatedValue: obj)
}

struct Accumulate<S: Sequence, T where T == S.GeneratorType.Element>
        : Sequence, Generator {
    var generator: S.GeneratorType
    var value: T?
    var f: ((T, T)->T)
    init(sequence: S, f: (T, T)->T) {
        self.generator = sequence.generate()
        self.value = generator.next()
        self.f = f
    }
    func generate() -> Accumulate<S, T> {
        return self
    }
    mutating func next() -> T? {
        let thisvalue = value
        if let nextvalue = generator.next() {
	    value = f(value!, nextvalue)
        } else { value = nil }
        return thisvalue
    }
}

func accumulate<S: Sequence, T where T == S.GeneratorType.Element>
        (sequence: S, f: (T, T)->T) -> Accumulate<S, T> {
    return Accumulate(sequence: sequence, f: f)
}

/* For some reason, this works if it's the last thing in the file, but causes
   a compiler error otherwise.
func cumulative_sum<S: Sequence, T where T == S.GeneratorType.Element, T: Addable>
        (sequence: S, f: (T, T)->T = { $0+$1 }) -> Accumulate<S, T> {
    return Accumulate(sequence: sequence, f: f)
}
*/

struct Chain<S: Sequence, T where T == S.GeneratorType.Element>
        : Sequence, Generator {
    var generators: S.GeneratorType[]
    init(sequences: S[]) {
        generators = []
        for sequence in sequences {
            generators.append(sequence.generate())
        }
    }
    func generate() -> Chain<S, T> {
        return self
    }
    mutating func next() -> T? {
        while true {
            if generators.isEmpty {
                return nil
            }
            if let value = generators[0].next() {
                return value
            }
            generators.removeAtIndex(0)
        }
    }
}

func chain<S: Sequence, T where T == S.GeneratorType.Element>
        (sequences: S...) -> Chain<S, T> {
    return Chain(sequences: sequences)
}

func chain_sequences<SS: Sequence, S: Sequence, T
                     where S == SS.GeneratorType.Element, 
                     T == S.GeneratorType.Element>
        (sequences: SS) -> Chain<S, T> {
    return Chain(sequences: array(sequences))
}

struct Compress<SD: Sequence, SS: Sequence, TD
                where TD == SD.GeneratorType.Element, 
                Bool == SS.GeneratorType.Element>
        : Sequence, Generator {
    var generator_d: SD.GeneratorType
    var generator_s: SS.GeneratorType
    init(data: SD, selectors: SS) {
        generator_d = data.generate()
        generator_s = selectors.generate()
    }
    func generate() -> Compress<SD, SS, TD> {
        return self
    }
    mutating func next() -> TD? {
        while true {
            if let (datum, selector) = zipopt(generator_d.next(), generator_s.next()) {
                if selector { return datum }
            } else {
                return nil
            }
        }
    }
}

func compress<SD: Sequence, SS: Sequence, TD
              where TD == SD.GeneratorType.Element, 
              Bool == SS.GeneratorType.Element>
        (data: SD, selectors: SS) -> Compress<SD, SS, TD> {
    return Compress(data: data, selectors: selectors)
}

/* It should be possible to get it to infer the sequence type for the
   sequence of Bool values that gets passed to Compress. But no matter
   what I try, I get an error somewhere--either unable to infer the
   types for map, or unable to convert the resulting mapped type to
   the type used for Compress. So I had to specify MapSequenceView
   explicitly, which is an implementation detail I shouldn't even know
   about.
*/
func compress_nz<SD: Sequence, SS: Sequence, TD
                 where TD == SD.GeneratorType.Element,
                 Int == SS.GeneratorType.Element>
        (data: SD, selectors: SS) -> Compress<SD, MapSequenceView<SS, Bool>, TD> {
    var mapped_selectors = map(selectors, { $0 != 0 })
    return Compress(data: data, selectors: mapped_selectors)
}

struct DropWhile<S: Sequence, T where T == S.GeneratorType.Element>
        : Sequence, Generator {
    var gen: S.GeneratorType
    var dropped = false
    let pred: T->Bool
    init(sequence: S, predicate: T->Bool) {
        gen = sequence.generate()
        pred = predicate
    }
    func generate() -> DropWhile<S, T> {
        return self
    }
    mutating func next() -> T? {
        if !dropped {
            dropped = true
            while let value = gen.next() {
                if !pred(value) {
                    return value
                }
            }
            return nil
        } else {
            return gen.next()
        }
    }
}

func dropwhile<S: Sequence, T where T == S.GeneratorType.Element>
        (sequence: S, predicate: T->Bool) -> DropWhile<S, T> {
    return DropWhile(sequence: sequence, predicate: predicate)
}

/* Since filter is built in, we might as well use it. As mentioned
   for map under compress_nz, there doesn't seem to be any way to
   get this to infer the return type, so we have to use a private
   type that's part of the implementation of filter... */
func filterfalse<S: Sequence, T where T == S.GeneratorType.Element>
        (sequence: S, predicate: T->Bool) -> FilterCollectionView<S> {
    return filter(sequence, negate(predicate))
}

struct GroupBy<S: Sequence, T, U: Equatable
  where T == S.GeneratorType.Element>
: Sequence, Generator {
  var gen: S.GeneratorType
  let keyfunc: T->U
  var currkey: U?
  var currvals: T[]
  init(sequence: S, key: T->U) {
    keyfunc = key
    gen = sequence.generate()
    currkey = nil
    currvals = []
  }
  func generate() -> GroupBy<S, T, U> {
    return self
  }
  mutating func next() -> (U, T[])? {
    if currkey == nil {
      if let currval = gen.next() {
        currvals = [currval]
        currkey = keyfunc(currval)
      } else {
        return nil
      }
    }
    while true {
      if let currval = gen.next() {
        let key = keyfunc(currval)
        if key == currkey {
          //println("Adding \(currval) to \(currvals) because \(key) == \(currkey)")
          currvals.append(currval)
        } else {
          let lastvals = currvals
          let lastkey = currkey!
          currvals = [currval]
          currkey = key
          //println("Returning \(lastkey), \(lastvals) because \(key) != \(lastkey)")
          return (lastkey, lastvals)
        }
      } else {
        if !currvals.isEmpty {
          //println("Done, returning last \(currkey), \(currvals)")
          let vals = currvals
          currvals = []
          return (currkey!, vals)
        } else {
          //print("Done, empty")
          return nil
        }
      }
    }
  }
}

/* As far as I can tell, there's no way to specify a the identity function
   as the default key function, making U the same type as T; the only thing
   you can do is write two separate functions. */   
func groupby<S: Sequence, T, U where T == S.GeneratorType.Element>
        (sequence: S, key: T->U) -> GroupBy<S, T, U> {
    return GroupBy(sequence: sequence, key: key)
}

func groupby_nokey<S: Sequence, T: Equatable where T == S.GeneratorType.Element>
        (sequence: S) -> GroupBy<S, T, T> {
    return GroupBy(sequence: sequence, key: { $0 })
}

struct ISlice<S: Sequence, T where T == S.GeneratorType.Element>
        : Sequence, Generator {
    var gen: S.GeneratorType
    let start: Int
    let stop: Int?
    let step: Int
    var pos: Int
    init(sequence: S, start: Int = 0, stop: Int? = nil, step: Int = 1) {
        self.gen = sequence.generate()
        self.start = start
	self.stop = stop
	self.step = step
	self.pos = 0
    }
    func generate() -> ISlice<S, T> {
        return self
    }
    mutating func next() -> T? {
        if pos < start {
            for _ in 0..start {
	        if let _ = gen.next() {
                } else {
                    return nil
                }
            }
            pos = start
        }
	if (stop != nil) && (pos > stop) {
            return nil
        }
        pos += step
        if let val = gen.next() {
            return val
        } else {
            return nil
        }
    }
}

func islice<S: Sequence, T where T == S.GeneratorType.Element>
        (sequence: S, start: Int = 0, stop: Int? = nil, step: Int = 1) 
        -> ISlice<S, T> {
    return ISlice(sequence: sequence, start: start, stop: stop, step: step)
}

/* starmap appears to be impossible, because (a) tuples aren't sequences,
   (b) there doesn't seem to be any way to convert from even a homogenous
   sequence to a tuple or vice-versa, and (c) even if you could, there
   doesn't seem to be any way to call a function given its arguments as
   a tuple. */

// Python itertools.takewhile
struct TakeWhile<S: Sequence, T where T == S.GeneratorType.Element>
        : Sequence, Generator {
    var gen: S.GeneratorType
    let pred: T->Bool
    init(sequence: S, predicate: T->Bool) {
        gen = sequence.generate()
        pred = predicate
    }
    func generate() -> TakeWhile<S, T> {
        return self
    }
    mutating func next() -> T? {
        if let val: T = gen.next() {
            if pred(val) { return val }
        }
        return nil
    }
}

func takewhile<S: Sequence, T where T == S.GeneratorType.Element>
              (sequence: S, predicate: T->Bool) 
              -> TakeWhile<S, T> {
    return TakeWhile(sequence: sequence, predicate: predicate)
}

/* tee should be possible, but every attempt ends in a compiler crash */

struct Zip<S0: Sequence, S1: Sequence, T0, T1
           where T0 == S0.GeneratorType.Element, T1 == S1.GeneratorType.Element>
        : Sequence, Generator {
    var generator0: S0.GeneratorType
    var generator1: S1.GeneratorType
    init(sequence0: S0, sequence1: S1) {
        generator0 = sequence0.generate()
        generator1 = sequence1.generate()
    }
    func generate() -> Zip<S0, S1, T0, T1> {
        return self
    }
    mutating func next() -> (T0, T1)? {
        if let (t0, t1) = zipopt(generator0.next(), generator1.next()) {
            return (t0, t1)
        }
        return nil
    }
}

func zip<S0: Sequence, S1: Sequence, T0, T1
         where T0 == S0.GeneratorType.Element, T1 == S1.GeneratorType.Element>
        (sequence0: S0, sequence1: S1) -> Zip<S0, S1, T0, T1> {
    return Zip(sequence0: sequence0, sequence1: sequence1)
}

struct ZipFill<S0: Sequence, S1: Sequence, T0, T1
               where T0 == S0.GeneratorType.Element, 
               T1 == S1.GeneratorType.Element>
        : Sequence, Generator {
    var generator0: S0.GeneratorType
    var generator1: S1.GeneratorType
    var fillvalue0: T0
    var fillvalue1: T1
    init(sequence0: S0, sequence1: S1, fillvalue0: T0, fillvalue1: T1) {
        self.generator0 = sequence0.generate()
        self.generator1 = sequence1.generate()
        self.fillvalue0 = fillvalue0
        self.fillvalue1 = fillvalue1
    }
    func generate() -> ZipFill<S0, S1, T0, T1> {
        return self
    }
    mutating func next() -> (T0?, T1?)? {
        if let t0 = generator0.next() {
	    if let t1 = generator1.next() {
                return (t0, t1)
            } else {
                return (t0, fillvalue1)
            }
        } else if let t1 = generator1.next() {
            return (fillvalue0, t1)
        } else {
            return nil
        }
    }
}

func zip_fill<S0: Sequence, S1: Sequence, T0, T1
              where T0 == S0.GeneratorType.Element, 
              T1 == S1.GeneratorType.Element>
        (sequence0: S0, sequence1: S1, fillvalue0: T0, fillvalue1: T1)
        -> ZipFill<S0, S1, T0, T1> {
    return ZipFill(sequence0: sequence0, sequence1: sequence1, 
                   fillvalue0: fillvalue0, fillvalue1: fillvalue1)
}

func zip_longest<S0: Sequence, S1: Sequence, T0, T1
                 where Optional<T0> == S0.GeneratorType.Element, 
                 Optional<T1> == S1.GeneratorType.Element>
        (sequence0: S0, sequence1: S1) -> ZipFill<S0, S1, T0?, T1?> {
    return ZipFill(sequence0: sequence0, sequence1: sequence1,
                   fillvalue0: nil, fillvalue1: nil)
}

/* Storing a bunch of Generators in an array makes each one immutable,
   which makes them completely useless. Without a way around that,
   there doesn't seem to be any way to implement Product, or anything
   else that works on a sequence of sequences... */
/*
struct Product<S: Sequence, T where T == S.GeneratorType.Element>
        : Sequence, Generator {
    var seqs: T[][]
    var gens: Array<T>.GeneratorType[]
    var vals: T[]?
    init(sequences: S[]) {
        seqs = []
        gens = []
        for seq in sequences {
            let aseq = array(seq)
            seqs.append(aseq)
            gens.append(aseq.generate())
        }
        // Can't pass explicitly-specialized generic like array<S, T>,
        // closure { array($0) } fails to infer type, and an
        // explicitly typed closure produces a slew of incomprehensible
        // and seemingly irrelevant errors. Presumably there's a bug in
        // the beta compiler, so just do things manually for now...
        // seqs = array(map(sequences, { array($0) }))
        // gens = array(map(seqs, { $0.generate() }))
        vals = nil
    }
    func generate() -> Product<S, T> {
        return self
    }
    mutating func next() -> T[]? {
        if vals == nil {
            vals = []
            for gen in gens {
                if let val: T = gen.next() {
                    vals!.append(val)
                } else {
                    return nil
                }
            }
            return vals
        } else {
            for i in (vals!.count-1)...0 {
                if let val: T = gens[i].next() {
                    vals![i] = val
                    return vals!
                } else {
                    gens[i] = seqs[i].generate()
                    if let val: T = gens[i].next() {
                        vals![i] = val
                    } else {
                        return nil
                    }
                }
            }
            return vals
        }
    }
}        

func product<S: Sequence, T where T == S.GeneratorType.Element>
        (sequences: S...) -> Product<S, T> {
    return Product(sequences: sequences)
}

func self_product<S: Sequence, T where T == S.GeneratorType.Element>
        (sequence: S, repeat: Int) -> Product<S, T> {
    return Product(sequences: S[](count: repeat, repeatedValue: sequence))
}
*/

struct Product2<S0: Sequence, S1: Sequence, T0, T1 
                where T0 == S0.GeneratorType.Element, 
                T1 == S1.GeneratorType.Element>
        : Sequence, Generator {
    var gen0: S0.GeneratorType
    var val0: T0?
    var seq1: T1[]
    var gen1: Array<T1>.GeneratorType
    init(sequence0: S0, sequence1: S1) {
        gen0 = sequence0.generate()
        val0 = gen0.next()
        seq1 = array(sequence1)
        gen1 = seq1.generate()
    }
    func generate() -> Product2<S0, S1, T0, T1> {
        return self
    }
    mutating func next() -> (T0, T1)? {
        if val0 == nil {
            if let val: T0 = gen0.next() {
                val0 = val
            } else {
                return nil
            }
        }
        if let val1: T1 = gen1.next() {
            return (val0!, val1)
        } else if let val: T0 = gen0.next() {
            val0 = val
            gen1 = seq1.generate()
            if let val1: T1 = gen1.next() {
                return (val0!, val1)
            } else {
                return nil
            }
        }
        // even though every path above has a return, the compiler
        // complains about a missing return...
        assert("can't get here")
        return nil
    }
}

func product2<S0: Sequence, S1: Sequence, T0, T1
              where T0 == S0.GeneratorType.Element, 
              T1 == S1.GeneratorType.Element>
        (sequence0: S0, sequence1: S1)
        -> Product2<S0, S1, T0, T1> {
    return Product2(sequence0: sequence0, sequence1: sequence1)
}

// Scala interpose
struct Interpose<S: Sequence, T where T == S.GeneratorType.Element>
        : Sequence, Generator {
    let sep: T
    var gen: S.GeneratorType
    var needSep: Bool
    var nextOrNil: T?

    init(separator: T, sequence: S) {
        self.sep = separator
        self.needSep = false
        self.gen = sequence.generate()
        self.nextOrNil = self.gen.next()
    }
    func generate() -> Interpose<S, T> {
        return self
    }
    mutating func next() -> T? {
        if needSep {
            needSep = false
            return sep
        } else {
            let n = nextOrNil
            if n {
                nextOrNil = gen.next()
                needSep = nextOrNil != nil
            }
            return n
        }
    }
}

func interpose<S: Sequence, T where T == S.GeneratorType.Element>
        (separator: T, sequence: S) -> Interpose<S, T> {
    return Interpose(separator: separator, sequence: sequence)
}

