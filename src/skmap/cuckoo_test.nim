import skyhash/blake2b

# tests assume 64-bit hashes
assert CuckooHash.sizeof == 8

proc do_the_thing(
    data: pointer;
    datalen: int;
    a, b: var CuckooHash) =
        var key1 = "one"
        var key2 = "two"
        blake2b(cast[pointer](addr a), data, cast[pointer](addr key1[0]),
                a.sizeof.uint, datalen.uint, 3.uint)
        blake2b(cast[pointer](addr b), data, cast[pointer](addr key2[0]),
                a.sizeof.uint, datalen.uint, 3.uint)

var hashmap: CuckooMap[int, string]
hashmap.init(20, do_the_thing)

var tests = 0
proc ok(x: bool; wot: string) =
    inc tests
    if x:
        echo "ok ", tests, " # ", wot
    else:
        echo "not ok ", tests, " # ", wot

echo "TAP version 13"

echo("# populate the map")
hashmap[29] = "incorrect"
ok(29 in hashmap, "cell 29 is populated")
ok(hashmap[29] == "incorrect", "cell 29 has correct value")
hashmap[6] = "staple"
ok(6 in hashmap, "cell 6 is populated")
ok(hashmap[6] == "staple", "cell 6 has correct value")
hashmap[555999] = "horse"
ok(555999 in hashmap, "cell 555999 is populated")
ok(hashmap[555999] == "horse", "cell 555999 has correct value")
hashmap[500] = "battery"
ok(500 in hashmap, "cell 500 is populated")
ok(hashmap[500] == "battery", "cell 500 has correct value")

echo("# overwrite an existing value")
hashmap[29] = "bonkers"
ok(29 in hashmap, "cell 29 is populated")
ok(hashmap[29] == "bonkers", "cell 29 has correct value")
hashmap[29] = "correct"

echo("# ensure all known values are correct")
ok(hashmap[29]     == "correct", "cell 29")
ok(hashmap[6]      == "staple",  "cell 6")
ok(hashmap[555999] == "horse",   "cell 555999")
ok(hashmap[500]    == "battery", "cell 500")

echo("# force a rehash")
for i in 1..40:
    hashmap[i+999999] = "x"

ok(true, "inserted lots of junk items")

echo("# ensure all known values are correct, once again")
ok(hashmap[29]     == "correct", "cell 29")
ok(hashmap[6]      == "staple",  "cell 6")
ok(hashmap[555999] == "horse",   "cell 555999")
ok(hashmap[500]    == "battery", "cell 500")

echo "1..",tests
