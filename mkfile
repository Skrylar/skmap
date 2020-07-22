modules=cuckoo robin
tests=${modules:%=t/%.t}

t:
    mkdir t

t/%.t: src/skmap/%.nim
    nim -o:$target c $prereq

check:V: $tests
    prove

