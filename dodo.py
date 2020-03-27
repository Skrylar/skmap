
algorithms = ['cuckoo', 'robin']

def task_test():
    """Runs tests against the hash table algorithms."""
    for alg in algorithms:
        yield {
        'name': alg,
        'actions': [
            'nim c -o:{0} -p:../skyhash/src src/skmap/{0}'.format(alg),
            './{0} | tappy'.format(alg)],
        'verbosity': 2,
        'targets': [alg]
        }

