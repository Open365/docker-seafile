#!/usr/bin/env python2.7
import os


seafile_setup = __import__('setup-seafile-mysql')


def do_dbs_exist(settings):
    db_checker = seafile_setup.ExistingDBConfigurator()
    for k, v in settings.iteritems():
        setattr(db_checker, k, v)
    try:
        db_checker.check_user_db_access('seafile-db')
        return True
    except seafile_setup.InvalidAnswer, e:
        print e
        return False


def get_settings():
    return {
        'mysql_host': 'mysql.service.consul',
        'mysql_port': 3306,
 
        'seafile_mysql_user': os.environ['MYSQL_SEAFILE_USER'],
        'seafile_mysql_password': os.environ['MYSQL_SEAFILE_PASSWORD']
    }

def main():
    settings = get_settings()

    if do_dbs_exist(settings):
        print "dbs seem to exist, exit 1"
        exit(1)
    else:
        print "dbs seem to NOT exist, exit 0"
        exit(0)

if __name__ == '__main__':
    main()
