# `trombik.argus`

[![Build Status](https://travis-ci.com/trombik/ansible-role-argus.svg?branch=master)](https://travis-ci.com/trombik/ansible-role-argus)

`ansible` role for `argus`.

## Notes for all users

The default path of the official package to `argus.conf(5)` is either
`/etc/argus.conf`, or `/usr/local/etc/argus.conf`, but this role defaults to
`/etc/argus/argus.conf`, or`/usr/local/etc/argus/argus.conf`.

The role assumes that the path to log directory, where captured `ra` file is
recorded, is `/var/log/argus`, and it is owned by `argus` user.

## Notes for all users except OpenBSD users

The role creates `argus` group and `argus` user.

## Notes for Ubuntu and CentOS users

The `systemd` unit file for `argus(8)` will be modified so that
`/etc/default/argus`, or `/etc/sysconfig/argus`, is read by `systemd`.

# Requirements

# Role Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `argus_package` | Package name of `argus` | `{{ __argus_package }}` |
| `argus_service` | Service name of `argus` | `{{ __argus_service }}` |
| `argus_extra_packages` | A list of extra package to install | `[]` |
| `argus_user` | User name of `argus` | `{{ __argus_user }}` |
| `argus_group` | Group name of `argus` | `{{ __argus_group }}` |
| `argus_extra_groups` | A list of extra groups for `argus_user` | `[]` |
| `argus_log_dir` | Path to log directory | `/var/log/argus` |
| `argus_config_dir` | Path to the configuration directory | `{{ __argus_config_dir }}` |
| `argus_config_file` | Path to `argus.conf` | `{{ argus_config_dir }}/argus.conf` |
| `argus_config` | The content of `argus.conf` | `""` |
| `argus_flags` | See below | `""` |

## `argus_flags`

This variable is used for overriding defaults for startup scripts. In Debian
variants, the value is the content of `/etc/default/argus`. In RedHat
variants, it is the content of `/etc/sysconfig/argus`. In FreeBSD, it
is the content of `/etc/rc.conf.d/argus`. In OpenBSD, the value is
passed to `rcctl set argus`.

## Debian

| Variable | Default |
|----------|---------|
| `__argus_service` | `argus` |
| `__argus_package` | `argus-server` |
| `__argus_config_dir` | `/etc/argus` |
| `__argus_user` | `argus` |
| `__argus_group` | `argus` |
| `__argus_log_dir` | `/var/log/argus` |

## FreeBSD

| Variable | Default |
|----------|---------|
| `__argus_service` | `argus` |
| `__argus_package` | `net-mgmt/argus3` |
| `__argus_config_dir` | `/usr/local/etc/argus` |
| `__argus_user` | `argus` |
| `__argus_group` | `argus` |
| `__argus_log_dir` | `/var/log/argus` |

## OpenBSD

| Variable | Default |
|----------|---------|
| `__argus_service` | `argus` |
| `__argus_package` | `argus` |
| `__argus_config_dir` | `/etc/argus` |
| `__argus_user` | `_argus` |
| `__argus_group` | `_argus` |
| `__argus_log_dir` | `/var/log/argus` |

## RedHat

| Variable | Default |
|----------|---------|
| `__argus_service` | `argus` |
| `__argus_package` | `argus` |
| `__argus_config_dir` | `/etc/argus` |
| `__argus_user` | `argus` |
| `__argus_group` | `argus` |
| `__argus_log_dir` | `/var/log/argus` |


# Dependencies

# Example Playbook

```yaml
---
- hosts: localhost
  roles:
    - role: trombik.redhat_repo
      when:
        - ansible_os_family == 'RedHat'
    - name: trombik.argus_clients
    - name: ansible-role-argus
  pre_tasks:
    - name: Dump all hostvars
      debug:
        var: hostvars[inventory_hostname]
  post_tasks:
    - name: List all services (systemd)
      # workaround ansible-lint: [303] service used in place of service module
      shell: "echo; systemctl list-units --type service"
      changed_when: false
      when:
        # in docker, init is not systemd
        - ansible_virtualization_type != 'docker'
        - ansible_os_family == 'RedHat' or ansible_os_family == 'Debian'
    - name: list all services (FreeBSD service)
      # workaround ansible-lint: [303] service used in place of service module
      shell: "echo; service -l"
      changed_when: false
      when:
        - ansible_os_family == 'FreeBSD'
  vars:
    os_argus_flags:
      OpenBSD: "-F {{ argus_config_file }}"
      FreeBSD: |
        argus_flags='-F {{ argus_config_file }}'
        argus_pidfile='/var/run/argus.{{ ansible_default_ipv4.device | default(omit) }}.*.pid'
      Debian: |
        ARGUS_OPTIONS="-F {{ argus_config_file }}"
      RedHat: |
        ARGUS_OPTIONS="-F {{ argus_config_file }}"
    argus_flags: "{{ os_argus_flags[ansible_os_family] }}"
    argus_extra_groups:
      - bin
    os_interface:
      FreeBSD: em0
      OpenBSD: em0
      Debian: eth0
      RedHat: eth0
    argus_config: |
      ARGUS_FLOW_TYPE="Bidirectional"
      ARGUS_FLOW_KEY="CLASSIC_5_TUPLE"
      {% if ansible_os_family != 'Debian' and ansible_os_family != 'RedHat' %}
      # XXX the unit file expects the command not to fork
      ARGUS_DAEMON=yes
      {% endif %}
      ARGUS_ACCESS_PORT=561
      ARGUS_BIND_IP="127.0.0.1"
      ARGUS_INTERFACE={{ os_interface[ansible_os_family] }}
      ARGUS_GO_PROMISCUOUS=yes
      ARGUS_SETUSER_ID={{ argus_user }}
      ARGUS_SETGROUP_ID={{ argus_group }}
      ARGUS_OUTPUT_FILE={{ argus_log_dir}}/argus.ra
      ARGUS_FLOW_STATUS_INTERVAL=60
      ARGUS_MAR_STATUS_INTERVAL=300
      ARGUS_DEBUG_LEVEL=1
      ARGUS_FILTER="ip"
      ARGUS_SET_PID=yes
      ARGUS_PID_PATH=/var/run
    redhat_repo_extra_packages:
      - epel-release
    redhat_repo:
      epel:
        mirrorlist: "http://mirrors.fedoraproject.org/mirrorlist?repo=epel-{{ ansible_distribution_major_version }}&arch={{ ansible_architecture }}"
        gpgcheck: yes
        enabled: yes
```

# License

```
Copyright (c) 2016 Tomoyuki Sakurai <y@trombik.org>

Permission to use, copy, modify, and distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
```

# Author Information

Tomoyuki Sakurai <y@trombik.org>
