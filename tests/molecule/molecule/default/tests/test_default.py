import os

import testinfra
import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def get_service_name(host):
    return 'argus'


def get_ansible_vars(host):
    return host.ansible.get_variables()


def get_ansible_facts(host):
    return host.ansible('setup')['ansible_facts']


def get_ping_target(host):
    ansible_vars = get_ansible_vars(host)
    if ansible_vars['inventory_hostname'] == 'server1':
        return 'client1' if is_docker(host) else '192.168.21.100'
    elif ansible_vars['inventory_hostname'] == 'client1':
        return 'server1' if is_docker(host) else '192.168.21.200'
    else:
        raise NameError(
                "Unknown host `%s`" % ansible_vars['inventory_hostname']
              )


def is_docker(host):
    ansible_facts = get_ansible_facts(host)
    if 'ansible_virtualization_type' in ansible_facts:
        if ansible_facts['ansible_virtualization_type'] == 'docker':
            return True
    return False


def get_listen_ports(host):
    return [561]


def test_hosts_file(host):
    f = host.file('/etc/hosts')

    assert f.exists
    assert f.user == 'root'
    assert f.group == 'root' or f.group == 'wheel'


def test_icmp_from_client(host):
    ansible_vars = get_ansible_vars(host)
    if ansible_vars['inventory_hostname'] == 'client1':
        target = get_ping_target(host)
        cmd = host.run("ping -c 1 -q %s" % target)

        assert cmd.succeeded


def test_icmp_from_server(host):
    ansible_vars = get_ansible_vars(host)
    if ansible_vars['inventory_hostname'] == 'server1':
        target = get_ping_target(host)
        cmd = host.run("ping -c 1 -q %s" % target)

        assert cmd.succeeded


def test_service(host):
    s = host.service(get_service_name(host))

    assert s.is_running
    assert s.is_enabled


def test_port(host):
    ports = get_listen_ports(host)

    for p in ports:
        assert host.socket("tcp://127.0.0.1:%d" % p).is_listening


def test_ra(host):
    with host.sudo():
        # read one IP record from argus on localhost:561
        cmd = host.run("ra -S localhost -N 1 ip")
        assert cmd.succeeded
