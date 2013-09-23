#!/bin/bash

set -eu

XSLIB=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)
REMOTELIB=$(cd $(dirname $(readlink -f "$0")) && cd remote && pwd)

function log_info() {
    echo -ne "\e[0;32m"
    cat
    echo -ne "\e[0m"
}


function log_error() {
    echo -ne "\e[0;31m"
    cat
    echo -ne "\e[0m"
}

function import_xva_from_url() {
    local xenserver
    local xva_location

    xenserver="$1"
    shift
    xva_location="$1"
    shift

    $REMOTELIB/bash.sh root@$xenserver << EOF
rm -f devstack.xva
wget -qO devstack.xva $xva_location
xe vm-import filename=devstack.xva > /dev/null
rm -f devstack.xva
EOF
}

function devstack_vm_stopped() {
    local xenserver

    xenserver="$1"
    shift

    $REMOTELIB/bash.sh root@$xenserver << EOF
[ "halted" = "\$(xe vm-list name-label=DevStackOSDomU params=power-state --minimal)" ]
EOF
}

function stop_devstack_vm() {
    local xenserver

    xenserver="$1"
    shift

    $REMOTELIB/bash.sh root@$xenserver << EOF
xe vm-shutdown name-label=DevStackOSDomU
while [ "halted" != "\$(xe vm-list name-label=DevStackOSDomU params=power-state --minimal)" ]; do
    sleep 1
    echo -n "."
done
echo ""
EOF
}

function start_devstack_vm() {
    local xenserver

    xenserver="$1"
    shift

    $REMOTELIB/bash.sh root@$xenserver << EOF
xe vm-start name-label=DevStackOSDomU
while [ "running" != "\$(xe vm-list name-label=DevStackOSDomU params=power-state --minimal)" ]; do
    sleep 1
    echo -n "."
done
EOF
}

function wait_for_devstack_network() {
    local xenserver

    xenserver="$1"
    shift

    $REMOTELIB/bash.sh root@$xenserver << EOF
while true; do
    IP=\$(xe vm-list name-label=DevStackOSDomU params=networks --minimal | sed -ne "s,^.*0/ip: \\([0-9.]*\\).*\\$,\1,p")
    if [ -z "\$IP" ]; then
        echo -n "."
        sleep 1
    else
        echo ""
        exit 0
    fi
done
EOF
}

function get_devstack_ip() {
    local xenserver

    xenserver="$1"
    shift

    $REMOTELIB/bash.sh root@$xenserver << EOF
xe vm-list name-label=DevStackOSDomU params=networks --minimal | sed -ne "s,^.*0/ip: \\([0-9.]*\\).*\\$,\1,p"
EOF
}

function on_devstack() {
    local devstack_ip

    devstack_ip="$1"
    shift

    sshpass -p "citrix" \
        ssh \
            -q \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            stack@$devstack_ip bash -s --
}

function wait_for_devstack() {
    local devstack_ip

    devstack_ip="$1"
    shift

    on_devstack $devstack_ip << EOF
while true; do
    if [ -e run.sh.log ]; then
        break
    fi
    sleep 1
    echo -n "."
done

while [ "\$(pgrep -c run.sh)" -ge 1 ]; do
    sleep 2
    echo -n "."
done

echo ""
# grep -q 'stack.sh completed in' run.sh.log
EOF
}

function devstack_succeeded() {
    local devstack_ip

    devstack_ip="$1"
    shift

    on_devstack $devstack_ip << EOF
grep -q 'stack.sh completed in' run.sh.log
EOF
}

function run_exercises() {
    local devstack_ip

    devstack_ip="$1"
    shift

    on_devstack $devstack_ip << EOF
cd /opt/stack/devstack
./exercise.sh </dev/null # >/opt/stack/exercises.result 2>&1
EOF
}

function run_smoke() {
    local devstack_ip

    devstack_ip="$1"
    shift

    on_devstack $devstack_ip << EOF
cd /opt/stack/tempest
nosetests -sv --nologcapture --attr=type=smoke tempest </dev/null # >/opt/stack/smoke.result 2>&1
EOF
}

function print_usage_and_die() {
    log_error << EOF
usage: $0 xenserver

Run tests against a devstack installation

$1
EOF
    exit 1
}

function main() {
    local xenserver

    set +u
    xenserver="$1"
    shift || print_usage_and_die "xenserver not specified"
    set -u

    cat << EOF
Listing parameters
------------------
xenserver:        $xenserver

EOF
    echo " - Is devstack running?"
    if devstack_vm_stopped $xenserver; then
        echo "   no" | log_info
    else
        echo "   yes" | log_info
        echo -n " - Stopping devstack vm"
        stop_devstack_vm $xenserver
        echo "   success" | log_info
    fi

    echo " - Starting devstack vm"
    start_devstack_vm $xenserver
    echo "   success" | log_info
    echo -n " - Waiting for network"
    wait_for_devstack_network $xenserver
    echo "   Interface 0 got an IP address" | log_info
    echo " - Retrieve devstack IP"
    devstack_ip=$(get_devstack_ip $xenserver)
    echo "   $devstack_ip" | log_info
    echo -n " - Waiting for devstack to complete"
    wait_for_devstack $devstack_ip
    echo "   devstack finished" | log_info
    echo " - Checking devstack scripts result"
    if devstack_succeeded $devstack_ip; then
        echo "   success" | log_info
    else
        echo "   fail" | log_error
        exit 1
    fi
    echo " - Running exercises"
    if run_exercises $devstack_ip; then
        echo "   success" | log_info
    else
        echo "   fail" | log_error
        exit 1
    fi
    echo " - Running smoke tests"
    if run_smoke $devstack_ip; then
        echo "   success" | log_info
    else
        echo "   fail" | log_error
    fi
}

main $@