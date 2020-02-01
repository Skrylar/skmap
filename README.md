
# Skrylar's Maps and Nimian Cartography

Unlike your typical stdlib map these maps come with the tuning values exposed. You provide the hash function to the map as well, so you can choose when you need a fast hash or a secure hash. You can also provide custom object hashes if you are using very strange keys that need special treatment.

## Cuckoo Hash

Cuckoo hash maps work by assigning two hashes to a single key: this can be a single larger hash function that is cut in to halves, two separate hashes, the same hash with different salts and so on. Important thing is each entry has two values that are usually not the same.

Values are placed at the position corresponding to its first or second hash. If both spots are taken then one of those space-takers gets evicted from the hotel and moved to its alternate position. That may involve another entry getting evicted which means we have to do it all over again.

This implementation's cycle protection is to check if we have evicted the entry that was *just* added, meaning a new map which is twice the size of the current map has to be created (called "rehashing.")

A cuckoo hash has O(1) retrieval and deletion, and insertion has an O(1) best case. The worst case? It... depends.

In the literature, cuckoo maps are sensitive to the hash function used along with them. High quality functions like SpookyHash 2 or MurmurHash 3 should be fine.

NOTE: Cuckoo does not have any collision resistance. If you attempt to insert three entries with identical hash 1 and hash 2 values but differing keys (malicious input, since the odds of *three* collisions with a good hash function are astronomical) the result is a shitshow and one of the values is not going to end up stored.

## Dependencies

For running the test suite:

  - [skyhash](https://git.sr.ht/~skrylar/skyhash).

## License

  - All modules in skmap are available under MPL-2.
