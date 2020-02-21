
# Skrylar's Maps and Nimian Cartography

Unlike your typical stdlib map these maps come with the tuning values
exposed. You provide the hash function to the map as well, so you can
choose when you need a fast hash or a secure hash. You can also provide
custom object hashes if you are using very strange keys that need
special treatment.

## Cuckoo Hash

WARNING: Cuckoo hashes are *probablistic*. If more than two entries have
the same hash result then things silently break down.

Cuckoo hash maps rely on two hash values for each entry. Items are
placed at their first location if that is possible, or their second
position if necessary. Because of this accesses are always O(1).

Hashes can be:

 - Two unrelated hash functions,
 - Two of the same hash functions with different salts, or,
 - Smaller pieces of one large key.

Rehashing is done if an item can not fit at either its first or second
location.

Cycle protection is implemented to avoid infinite loops. It works by
stopping insertion if we ever find outself trying to move the element
just added. In that case insertion is aborted and a rehash is triggered.

Cuckoo maps are very sensitive to the hash function used
along with them. High quality functions like SpookyHash 2 or MurmurHash
3 should be fine.

TODO: It should be possible to detect and alert on triple collisions.

## Dependencies

For running the test suite:

  - [skyhash](https://git.sr.ht/~skrylar/skyhash).

## License

  - All modules in skmap are available under MPL-2.
