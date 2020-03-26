
algorithms = ['cuckoo', 'robin']

def task_test():
    """Runs tests against the hash table algorithms."""
    for alg in algorithms:
        yield {
        'name': alg,
        'actions': [
            'nim c -o:{} -p:../skyhash/src src/skmap/cuckoo'.format(alg),
            './{} | tappy'.format(alg)],
        'verbosity': 2,
        'targets': [alg]
        }

