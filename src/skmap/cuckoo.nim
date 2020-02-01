
type
    CuckooHash* = uint64
    CuckooHashFunction* = proc(data: pointer; datalen: int; a, b: var CuckooHash) {.closure.}

    CuckooMapEntry[K,V] = object
        occupied:     bool
        hash1, hash2: CuckooHash # cuckoo keeps two hashes
        key:          K
        value:        V

    CuckooMap*[K,V] = object
        entries: seq[CuckooMapEntry[K,V]]
        filled:  int
        hash:    CuckooHashFunction

proc init*[K,V](self: var CuckooMap[K,V]; initial_length: int; hash: CuckooHashFunction) =
    ## Initializes a map for use.
    assert initial_length >= 0

    # clear any previous data
    set_len(self.entries, 0)
    zeromem(addr self, self.sizeof)

    # prepare the array for new things
    set_len(self.entries, initial_length)
    self.hash = hash

proc len*[K,V](self: CuckooMap[K,V]):int =
    ## Return the number of key/value pairs stored in the map.
    return self.entries.filled

proc derive_hashes[K,V](self: CuckooMap[K,V]; input: pointer; inlen: int; a, b: var CuckooHash) =
    ## Machinery to derive both cuckoo hashes from a given input.
    assert self.hash != nil
    self.hash(input, inlen, a, b)

iterator items*[K,V](self: CuckooMap[K,V]): (K, V) =
    ## Iterates through each key/value pair in the map.
    for x in self.entries:
        if not x.occupied: continue
        yield (x.key, x.value)

iterator keys*[K,V](self: CuckooMap[K,V]): K =
    ## Iterates through each key in the map.
    for x in self.entries:
        if not x.occupied: continue
        yield x.value

iterator values*[K,V](self: CuckooMap[K,V]): V =
    ## Iterates through each value in the map.
    for x in self.entries:
        if not x.occupied: continue
        yield x.value

proc try_get*[K,V](self: CuckooMap[K,V]; whence: K; wot: var V): bool =
    ## Checks if a key with a particular value exists within the map.
    var a, b: CuckooHash
    self.derive_hashes(unsafeaddr whence, whence.sizeof, a, b)

    let am = (a mod self.entries.len.CuckooHash).int
    if self.entries[am].occupied and (self.entries[am].key == whence):
        wot = self.entries[am].value
        return true

    let bm = (b mod self.entries.len.CuckooHash).int
    if self.entries[bm].occupied and (self.entries[bm].key == whence):
        wot = self.entries[bm].value
        return true

    return false

proc contains*[K,V](self: CuckooMap[K,V]; whence: K): bool =
    ## Checks if a key with a particular value exists within the map.
    var holder: V
    return self.try_get(whence, holder)

proc `[]`*[K,V](self: CuckooMap[K,V]; whence: K): V =
    ## If the key was found in the map, return the value stored
    ## there. Otherwise raises a ValueError.
    if not self.try_get(whence, result):
        raise new_exception(ValueError, "Key not found in CuckooMap")

proc put*[K,V](self: var CuckooMap[K,V]; whence: K; wot: V) =
    var a, b: CuckooHash
    self.derive_hashes(unsafeaddr whence, whence.sizeof, a, b)

    let entry_count = self.entries.len

    # HOW CUCKOO "PUTS" WORK
    #  - Try to put something at its first or second hash, then
    #  - Bump whoever is there to their opposing hash, then
    #  - Rehash to a larger blob, then
    #  - Sob profusely and detonate

    var position: bool

    var cup: CuckooMapEntry[K,V]  # Holds current insertion target
    var temp: CuckooMapEntry[K,V] # Used during swaps

    cup.occupied = true
    cup.hash1    = a
    cup.hash2    = b
    cup.key      = whence
    cup.value    = wot

    var am = (cup.hash1 mod entry_count.CuckooHash).int
    var bm = (cup.hash2 mod entry_count.CuckooHash).int

    # short-circuit attempt to update an existing entry
    if self.entries[am].occupied and (self.entries[am].key == cup.key):
        self.entries[am] = cup
        return
    if self.entries[bm].occupied and (self.entries[bm].key == cup.key):
        self.entries[bm] = cup
        return

    inc self.filled

    # long haul: have to bounce entries around
    while true:
        am = (cup.hash1 mod entry_count.CuckooHash).int
        bm = (cup.hash2 mod entry_count.CuckooHash).int

        # if there is an empty cell, go ahead and put it there
        if self.entries[am].occupied == false:
            self.entries[am] = cup
            return
        elif self.entries[bm].occupied == false:
            self.entries[bm] = cup
            return

        # put swap target in temp and store cup in the map
        temp = self.entries[am]
        var cm = (temp.hash1 mod entry_count.CuckooHash).int
        position = (cm == am)
        self.entries[am] = cup

        # try to switch temp between its first and second position when it gets hopped
        if position:
            cm = (temp.hash2 mod entry_count.CuckooHash).int

        # now put who we swapped out in their alternate position, with
        # the entry *that* displaced becoming the new cup
        cup = self.entries[cm]
        self.entries[cm] = temp

        if cup.occupied == false:
            return

        # XXX could check the hashes first as a micro-optimization to
        # rule out multiple long but similar keys
        if cup.key == whence:
            # !!! we have encountered a cycle and need to rehash
            var replacement: CuckooMap[K,V]
            init(replacement, max(1, self.entries.len) * 2, self.hash)
            for k, v in self.items:
                replacement.put(k, v)
            self = replacement
            return

proc `[]=`*[K,V](self: var CuckooMap[K,V]; whence: K; wot: V) {.inline.} =
    ## Puts the given value in the map specificed by the key.
    self.put(whence, wot)

proc del*[K,V](self: var CuckooMap[K,V]; whence: K) =
    # HOW CUCKOO "DELETES" WORK
    #  - Just remove the entry's cell

    var a, b: CuckooHash
    self.derive_hashes(unsafeaddr whence, whence.sizeof, a, b)

    let ap = a mod self.entries.len
    let bp = b mod self.entries.len

    if self.entries[ap].key == K:
        self.entries[ap].occupied = false
        self.entries[ap].key      = typeof(self.entries[ap].key).init
        self.entries[ap].value    = typeof(self.entries[ap].value).init
        dec self.filled
        return

    if self.entries[bp].key == K:
        self.entries[bp].occupied = false
        self.entries[bp].key      = typeof(self.entries[bp].key).init
        self.entries[bp].value    = typeof(self.entries[bp].value).init
        dec self.filled
        return

when is_main_module:
    include cuckoo_test
