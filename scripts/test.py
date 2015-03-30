import socket
import functools
import time
import retrying

import MySQLdb
import netaddr
import sqlalchemy as sa

import argparse
import itertools
import collections
from oslo.db import exception as db_exc

from multiprocessing import Pool

def select_for_update(connection_string):
    print 'SELECT_FOR_UPDATE'
    eng = sa.create_engine(connection_string, echo=False)
    conn = eng.connect()

    result = collections.defaultdict(int)
    node_host = eng.url.host

    def _retry_on_deadlock(f):
        """Decorator to retry a DB API call if Deadlock was received."""
        @functools.wraps(f)
        def wrapped(*args, **kwargs):
            while True:
                try:
                    return f(*args, **kwargs)
                except (db_exc.DBDeadlock, MySQLdb.OperationalError, sa.exc.OperationalError):
                    # print "Deadlock detected when running !!!"
                    result['retry_on_deadlock'] += 1
                    # Retry!
                    time.sleep(0.5)
                    continue
        functools.update_wrapper(wrapped, f)
        return wrapped

    @_retry_on_deadlock
    def make_update():

        while True:
            try:

                with conn.begin():
                    expr = "select id, fixed_ip, host from test_fixed_ips where host is null order by id limit 1 for update"
                    row = conn.execute(expr).fetchone()
                    result['selects'] += 1
                    id, fixed_ip, host = row[0], row[1], row[2]
                    # print id, ' ', fixed_ip

                    expr = "update test_fixed_ips set host = %(host)s where id = %(id)s"
                    conn.execute(expr, {'id': id, 'host': node_host})
                    result['updates'] += 1
                    result['commits'] += 1

            except (AttributeError, TypeError) as e:
                print str(e)
                print 'no ips left'
                break

    make_update()
    return result

def compare_and_swap(connection_string):
    print 'COMPARE_AND_SWAP'
    eng = sa.create_engine(connection_string, echo=False, execution_options={'isolation_level': "AUTOCOMMIT"})

    result = collections.defaultdict(int)
    node_host = eng.url.host

    def _retry_on_deadlock(f):
        """Decorator to retry a DB API call if Deadlock was received."""
        @functools.wraps(f)
        def wrapped(*args, **kwargs):
            while True:
                try:
                    return f(*args, **kwargs)
                except (db_exc.DBDeadlock, MySQLdb.OperationalError, sa.exc.OperationalError):
                    # print "Deadlock detected when running !!!"
                    result['retry_on_deadlock'] += 1
                    # Retry!
                    time.sleep(0.5)
                    continue
        functools.update_wrapper(wrapped, f)
        return wrapped

    @_retry_on_deadlock
    @retrying.retry(retry_on_exception= lambda exc: isinstance(exc, ImportError), wait_random_min=0, wait_random_max=300)
    def make_update():

        while True:
            with eng.connect() as conn:
                try:
                    expr = "select id, fixed_ip, host from test_fixed_ips where host is null order by id limit 1"
                    row = conn.execute(expr).fetchone()
                    result['selects'] += 1
                    id, fixed_ip, host = row[0], row[1], row[2]

                    # print id, ' ', fixed_ip
                except (AttributeError, TypeError) as e:
                    print str(e)
                    print 'no ips left'
                    break

                expr = "update test_fixed_ips set host = %(host)s where host is null and id = %(id)s and fixed_ip = %(fixed_ip)s"
                result_exec = conn.execute(expr, {'id': id, 'host': node_host, 'fixed_ip': fixed_ip})
                result['updates'] += 1
                rows_updated = result_exec.rowcount

                if not rows_updated:
                    # print '0 rows updated'
                    result['retry_on_no_rows_updated'] += 1
                    # Retry!
                    raise ImportError()

                result['commits']+= 1

    make_update()
    return result

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--processes', dest='processes', type=int, action='store', nargs=1, required=True,
                   help='number of processes')
    parser.add_argument('--netsize', dest='netsize', type=int, action='store', nargs=1, required=True,
                   help='network size')
    parser.add_argument('--db', dest='db', action='store', nargs='+', required=True,
                   help='sqlalchemy connection string')
    parser.add_argument('--cas', dest='type', action='store_const',
                   const=compare_and_swap, default=select_for_update,
                   help='when set compare_and_swap is used')

    args = parser.parse_args()
    print 'args = ', args

    cred = args.db[0]

    eng = sa.create_engine(cred, echo=False, execution_options={'isolation_level': "AUTOCOMMIT"})

    table = sa.Table(
        'test_fixed_ips', sa.MetaData(),
        sa.Column('id', sa.Integer, primary_key=True),
        sa.Column('fixed_ip', sa.String(64)),
        sa.Column('host', sa.String(32)),
        mysql_engine='innodb'
    )

    with eng.connect() as conn:
        table.drop(conn, checkfirst=True)
        table.create(conn)
        conn.execute(table.insert(), [{'fixed_ip': str(ip)} for ip in netaddr.IPNetwork('192.168.0.0/' + str(args.netsize[0]))]) # number of ips created
        print 'TABLE WAS CREATED /' + str(args.netsize[0])

    # WTF?????
    time.sleep(40)

    processes = args.processes[0]
    print 'Creating pool with %d processes\n' % processes
    pool = Pool(processes=processes)

    start_time = time.time()
    tasks = list(itertools.islice(itertools.cycle(args.db), 0, processes))
    result = pool.map(args.type, tasks)

    total_result = collections.defaultdict(int)
    for d in result:
        print d
        for key in d:
            total_result[key] += d[key]

    print '--------------------------------------------------------'
    print 'TOTAL RESULT'
    print total_result
    print '--------------------------------------------------------'
    time_in_seconds = (time.time() - start_time);
    print("time %s seconds" % str(time_in_seconds))
    print("time %s minutes" % str(time_in_seconds / 60.0))
    print '--------------------------------------------------------'

if __name__ == "__main__":
    main()

