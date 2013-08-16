import sys
import os
import argparse
import paramiko
import json


def create_query_expression(owners):
    return '( ' + ' OR '.join('owner:%s' % owner for owner in owners) + ') '


def main(args):
    hostname = args.host
    port = int(args.port)
    username = args.username
    keyfile = args.keyfile
    owners = args.watched_owners.split(',')

    client = paramiko.SSHClient()
    client.load_system_host_keys()
    client.set_missing_host_key_policy(paramiko.WarningPolicy())
    client.connect(hostname, port=port, username=username, key_filename=keyfile)
    stdin, stdout, stderr = client.exec_command(
        "gerrit query --patch-sets --format=JSON status:open AND %s" %
            create_query_expression(owners))


    def to_change_line(change):
        if 'patchSets' not in change:
            return
        patchsets = [(int(ps['number']), ps['ref']) for ps in change['patchSets']]
        latest_patchset = sorted(patchsets, key=lambda x: x[0], reverse=True)[0]

        project = change['project']


        return (project, latest_patchset[1])


    proj_refs = []
    for line in stdout.readlines():
        change = json.loads(line)
        proj_ref = to_change_line(change)
        if proj_ref:
            proj_refs.append(proj_ref)


    for proj_ref in sorted(proj_refs):
        sys.stdout.write("%s %s\n" % proj_ref)

    client.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='Get changes repo from OpenStack gerrit')
    parser.add_argument('username', help='Gerrit username to use')
    parser.add_argument('keyfile', help='SSH key to use')
    parser.add_argument('watched_owners',
        help='Comma separated list of Owner ids whose changes to be collected')
    parser.add_argument('--host', default='review.openstack.org',
        help='Specify a host. default: review.openstack.org')
    parser.add_argument('--port', default='29418',
        help='Specify a port. default: 29418')
    args = parser.parse_args()
    main(args)
