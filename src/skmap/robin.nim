
type
    RobinHoodHash* = uint64
    RobinHoodHashFunction* = proc(data: pointer; datalen: int; a: var RobinHoodHash) {.closure.}

    Infobyte* = distinct uint8
    Distance* = range[0..15]

    RobinHoodMapEntry*[K,V] = object
        infobyte: Infobyte
        hash:     RobinHoodHash
        key:      K
        value:    V

    RobinHoodMap*[K,V] = object
        entries: seq[RobinHoodMapEntry[K,V]]
        filled:  int
        hash:    RobinHoodHashFunction

proc full*(self: Infobyte): bool =
    ## Retrieves whether or not the "full" flag is set, indicating the
    ## map entry contains some data.
    return (self.uint and 0x80) != 0

proc `full=`*(self: var Infobyte; neo: bool) =
    ## Sets the value of the full flag.
    if neo:
        self = (self.uint or 0x80).Infobyte
    else:
        self = (self.uint and 0x7F).Infobyte

proc distance*(self: Infobyte): Distance =
    ## Returns the distance of a map entry from its native bucket.
    return (self.int and 0x7F).Distance

proc `distance=`*(self: var Infobyte; dist: Distance) =
    ## Sets the distance of a map entry from its native bucket.
    let fwoof = self.full
    if fwoof:
        self = (dist.uint8 + 0x80).Infobyte
    else:
        self = dist.uint8.Infobyte

proc clear[K,V](self: var RobinHoodMapEntry[K,V]) =
    self.infobyte = 0.Infobyte
    self.hash     = 0.RobinHoodHash
    self.key      = default(K)
    self.value    = default(V)

proc init*[K,V](self: var RobinHoodMap[K,V]; initial_length: int; hash: RobinHoodHashFunction) =
    ## Initializes a map for use.
    assert initial_length >= 0

    # clear any previous data
    set_len(self.entries, 0)
    zeromem(addr self, self.sizeof)

    # prepare the array for new things
    set_len(self.entries, initial_length)
    self.hash = hash

proc len*[K,V](self: RobinHoodMap[K,V]):int =
    ## Return the number of key/value pairs stored in the map.
    return self.filled

proc derive_hashes[K,V](self: RobinHoodMap[K,V]; input: pointer; inlen: int; a: var RobinHoodHash) =
    ## Machinery to derive both cuckoo hashes from a given input.
    assert self.hash != nil
    self.hash(input, inlen, a)

proc derive_hashes[K:string,V](self: RobinHoodMap[K,V]; input: K; a: var RobinHoodHash) =
    ## Machinery to derive both cuckoo hashes from a given input.
    assert self.hash != nil
    self.hash(unsafeaddr input[0], input.len, a)

proc derive_hashes[K,V](self: RobinHoodMap[K,V]; input: K; a: var RobinHoodHash) =
    ## Machinery to derive both cuckoo hashes from a given input.
    assert self.hash != nil
    self.hash(unsafeaddr input, input.sizeof, a)

iterator items*[K,V](self: RobinHoodMap[K,V]): (K, V) =
    ## Iterates through each key/value pair in the map.
    for x in self.entries:
        if not x.infobyte.full: continue
        yield (x.key, x.value)

iterator raw_items*[K,V](self: seq[RobinHoodMapEntry[K,V]]): RobinHoodMapEntry[K,V] =
    ## Iterates through each key/value pair in the map.
    for x in self:
        if not x.infobyte.full: continue
        yield x

iterator keys*[K,V](self: RobinHoodMap[K,V]): K =
    ## Iterates through each key in the map.
    for x in self.entries:
        if not x.infobyte.full: continue
        yield x.key

iterator values*[K,V](self: RobinHoodMap[K,V]): V =
    ## Iterates through each value in the map.
    for x in self.entries:
        if not x.infobyte.full: continue
        yield x.value

proc find_bucket*[K,V](self: RobinHoodMap[K,V], whence: K; wot: var int): bool =
    ## Checks if a key with a particular value exists within the map.
    var a: RobinHoodHash
    self.derive_hashes(whence, a)

    # check if its stored at its native slot
    let am = (a mod self.entries.high.RobinHoodHash).int
    if self.entries[am].infobyte.full and (self.entries[am].key == whence):
        wot = am
        return true

    # now we have to check the neighborhood for a result
    for i in 0..Distance.high:
        let ami = (am + i) mod self.entries.high

        # skip empty cells
        # XXX we might could do an early exit, but we would need to
        # patch put/delete to ensure gaps were filled in
        if self.entries[ami].infobyte.full == false:
            continue

        # if we reached the key then we are done
        if self.entries[ami].key == whence:
            wot = ami
            return true

    return false

proc try_get*[K,V](self: RobinHoodMap[K,V]; whence: K; wot: var V): bool =
    var index: int
    if find_bucket(self, whence, index):
        wot = self.entries[index].value
        return true
    else:
        return false

proc contains*[K,V](self: RobinHoodMap[K,V]; whence: K): bool =
    ## Checks if a key with a particular value exists within the map.
    var holder: V
    return self.try_get(whence, holder)

proc `[]`*[K,V](self: RobinHoodMap[K,V]; whence: K): V =
    ## If the key was found in the map, return the value stored there.
    ## Otherwise raises a ValueError.
    if not self.try_get(whence, result):
        raise new_exception(ValueError, "Key not found in RobinHoodMap")

proc put*[K,V](self: var RobinHoodMap[K,V]; whence: K; wot: V) =
    assert self.entries.len > 0

    var a: RobinHoodHash
    self.derive_hashes(whence, a)

    # HOW ROBIN “PUTS” WORK
    #
    #   - Try to put something at its native hash cell, then
    #   - Find an unclaimed cell within the neighborhood of the native
    #     cell,
    #   - If there is no available space then rehash to a larger blob.
    #
    # When inserting we are allowed to toss any element to another
    # position so long as its within `Distance.high` cells of its native
    # hash.
    #
    # A cell’s native position is the bucket determined by the modulus
    # of its hash value against the size of our array.

    # best-case scenario: bucket is empty, just plop it in
    let am = (a mod self.entries.high.RobinHoodHash).int
    for i in 0..Distance.high:
        # TODO pretty sure we are supposed to bump existing items during this
        let ami = (am + i) mod self.entries.high
        template here: untyped = self.entries[ami]
        # TODO check if the distance is in the correct neighborhood (saves some full comparisons)
        if (here.infobyte.full == false) or (here.key == whence):
            # only increase fill count on legit new item
            if here.key != whence:
                inc self.filled
            here.infobyte.full     = true
            here.infobyte.distance = i
            here.hash              = a
            here.key               = whence
            here.value             = wot
            return

    # Reaching this position means we were not able to find a bucket.
    # That means we have to do a rehash. Rehashing looks like this:
    #
    #   - Double the size of our backing array (XXX doubling is a widely
    #     used practice with some academic background; what is the
    #     actual reason though?)
    #   - Maintain a cursor for an entry currently worked on,
    #   - Walk over the backing store
    #       - If the cursor is empty then we move to the next cell in
    #         the array
    #       - If the cursor is not empty then we throw it to its new
    #         rightful bucket
    #           - Make sure that other members of the new neighborhood
    #             belong there; if it does not belong then swap the
    #             cursor with the misfit element

    block rehash:
        var oldmark = self.entries.len
        var i: int
        template grow() =
            i = 0
            oldmark = self.entries.len
            set_len(self.entries, max(self.entries.len * 2, 1))
        grow()

        var cursor: RobinHoodMapEntry[K,V]

        inc self.filled
        cursor.infobyte.full     = true
        cursor.hash              = a
        cursor.key               = whence
        cursor.value             = wot

        while i < oldmark:
            # lift to cursor
            if cursor.infobyte.full == false:
                if self.entries[i].infobyte.full == false:
                    inc i
                    continue
                else:
                    cursor = self.entries[i]
                    self.entries[i].clear
                    inc i

            block dropcursor:
                let am = (cursor.hash mod self.entries.high.RobinHoodHash).int
                for i in 0..Distance.high:
                    # TODO pretty sure we are supposed to bump existing items during this
                    let ami = (am + i) mod self.entries.high
                    template here: untyped = self.entries[ami]
                    # try to place in to a free area
                    if (here.infobyte.full == false) or
                        (here.key == cursor.key):
                            here = cursor
                            here.infobyte.distance = i
                            cursor.infobyte.full = false
                            break dropcursor
                    else:
                        let rightful = (here.hash mod self.entries.high.RobinHoodHash).int
                        let contender = (ami - here.infobyte.distance.int) mod self.entries.high.int
                        if rightful != contender:
                            let temp = here
                            here = cursor
                            here.infobyte.distance = i
                            cursor = temp
                            break dropcursor
                grow()

proc `[]=`*[K,V](self: var RobinHoodMap[K,V]; whence: K; wot: V) {.inline.} =
    ## Puts the given value in the map specificed by the key.
    self.put(whence, wot)

proc del*[K,V](self: var RobinHoodMap[K,V]; whence: K) =
    # HOW ROBIN “DELETES” WORK
    #   - Just remove the entry’s cell
    #   - TODO Optionally you could defrag the array if you wanted

    var index: int
    if find_bucket(self, whence, index):
        self.entries[index].clear()
        dec self.filled

when is_main_module:
    include robin_test
