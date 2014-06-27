func make_isprime() -> (Int -> Bool) {
    var memo = Int[]()
    func isprime(n: Int) -> Bool {
        for prime in memo {
            if n % prime == 0 { return false }
	}
        memo.append(n)
        return true
    }
    return isprime
}

func intifyarg1() -> Int? {
    if C_ARGC == 2 {
        let limitstr = String.fromCString(C_ARGV[1])
	if let limit = limitstr.toInt() {
	    return limit
        }
    }
    return nil
}

/*
if let limit = intifyarg1() {
    let primes = filter(count(start: 2), make_isprime())
    let limited = takewhile(primes, { $0 <= limit })
    let s = " ".join(map(limited, { $0.description }))
    println("\(s)")
} else {
    println("\(C_ARGV[0]) LIMIT")
}
*/

println("*** groupby/islice ***")
let a = [0, 0, 0, 1, 1, 2, 2, 2, 3]
let g = groupby_nokey(a)
for (key, group) in islice(g, start: 1) {
    println("\(key): \(group)")
}

println("*** groupby/take ***")
let g2 = groupby_nokey(a)
for (key, group) in take(g2, 2) {
    println("\(key): \(group)")
}

println("*** zip ***")
let b = [1, 2, 3]
let c = ["spam", "eggs"]
for t in zip(b, c) {
    println("\(t)")
}

println("*** product2 ***")
for t in product2(b, c) {
    println("\(t)")
}

println("*** product ***")
for t in product(c, c, c) {
    println("\(t)")
}

println("*** self_product ***")
for t in self_product(c, 2) {
    println("\(t)")
}

println("*** tabulate/take ***")
let squares = tabulate({ $0*$0 })
let squares15 = take(squares, 5)
println("\(squares15)")
let squares1a = tabulate_n(1, { $0*$0 })
let squares15a = take(squares1a, 4)
println("\(squares15a)")

/*
for (key, group) in groupby(a, { $0 / 2 }) {
    println("\(key): \(group)")
}
*/
