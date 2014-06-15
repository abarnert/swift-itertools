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

// Scala interpose
struct Interpose<S: Sequence, T where T == S.GeneratorType.Element>
        : Sequence, Generator {
    typealias Element = T
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
