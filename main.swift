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

if let limit = intifyarg1() {
    let primes = filter(count(start: 2), make_isprime())
    let limited = takewhile(primes, { $0 <= limit })
    let s = " ".join(map(limited, { $0.description }))
    println("\(s)")
} else {
    println("\(C_ARGV[0]) LIMIT")
}
