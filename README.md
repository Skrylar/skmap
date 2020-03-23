
# Skrylar’s Maps and Nimian Cartography

Unlike your typical stdlib map these maps come with the tuning values
exposed. You provide the hash function to the map as well, so you can
choose when you need a fast hash or a secure hash. You can also provide
custom object hashes if you are using very strange keys that need
special treatment.

## Hopscotch Hashes

Hopscotch hashes appear whenever Cuckoo hashes are mentioned. Research
has turned up that Robin Hood hashes are similar but perform better.
Therefore Hopscotch has not been implemented here.

  - http://codecapsule.com/2013/08/11/hopscotch-hashing/

## Robin Hood Hashes

Robin Hood maps are similar to the ubiquitous open address maps with
linear probing. A single hash of an input value determines the object's
native bucket. Like most open addresed linear probing maps, objects
may be placed later in the array than their native bucket. This allows
memory usage to remain denser than other maps (ex. Cuckoo maps.)

Like a Hopscotch map, Robin Hoods rely on objects belonging to
neighborhoods. Each cell knows how far it is from its native cell. There
is also an upper search limit, which places a hard bound on how much
linear probing can degrade performance.

These tables will test at most 16 cells when attempting to find a value.
Cells within the neighborhood will be checked for fullness, then checked
to see if they belong to the same bucket as the item being located.
These checks reduce the number of times keys must be checked; so most of
those 16 comparisons will usually be reduced comparisons and not full
key equality checks.

  - “Very Fast HashMap in C++: Hopscotch & Robin Hood Hashing (Part 1)”.
    Martin Ankerl.
    https://martin.ankerl.com/2016/09/15/very-fast-hashmap-in-c-part-1/

  - “Very Fast HashMap in C++: Implementation Variants (Part 2)”. Martin
    Ankerl.
    https://martin.ankerl.com/2016/09/21/very-fast-hashmap-in-c-part-2/

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

- "Cuckoo hashing". Wikipedia. https://en.wikipedia.org/wiki/Cuckoo_hashing

## Dependencies

For running the test suite:

  - [skyhash](https://git.sr.ht/~skrylar/skyhash).

## License

  - All modules in skmap are available under MPL-2.
