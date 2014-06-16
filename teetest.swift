struct TeeHelper<S: Sequence, T where T == S.GeneratorType.Element> {
    var gen: S.GeneratorType
    var queues: T[][]
}

struct Tee<S: Sequence, T where T == S.GeneratorType.Element>
        : Sequence, Generator {
    var helper: TeeHelper<S, T>
    var i: Int
    func generate() -> Tee<S, T> { return self }
    mutating func next() -> T? {
        if helper.queues[i].isEmpty {
            if let val = helper.gen.next() {
                /* iterating over queues gives us immutable copies of each! */
                for i in 0..helper.queues.count {
                    helper.queues[i].append(val)
                }
            } else {
                return nil
            }
        }
        return helper.queues[i].removeAtIndex(0)
    }
}

func tee<S: Sequence, T where T == S.GeneratorType.Element>
        (sequence: S, n: Int = 2) -> Tee<S, T>[] {
    return []
/*
    var gen = sequence.generate()
    var queues: T[][] = []
    var helper = TeeHelper<S, T>(gen: gen, queues: queues)
    var tees: Tee<S, T>[] = []
    for i in 0..n {
        tees.append(Tee(helper: helper, i: i))
        helper.queues.append([])
    }
    return tees
*/
}

var seq = [1, 2, 3]
var g = seq.generate()
var t = tee(g, n: 3)
for val in t[0] {
    println("\(val)")
}
for val in t[0] {
    println("\(val)")
}
for val in t[2] {
    println("\(val)")
}
