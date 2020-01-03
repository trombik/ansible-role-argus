require "spec_helper"
require "serverspec"

package = "argus"
service = "argus"
config_dir = "/etc"
config_mode = 640
user = "argus"
group = "argus"
log_dir = "/var/log/argus"
log_file = "#{log_dir}/argus.ra"
default_user = "root"
default_group = "wheel"
log_dir_mode = 755
# XXX it seems like there is no option to set file mode
log_mode = 644
ports = [561]
extra_groups = %w[bin]
extra_packages = []

case os[:family]
when "openbsd"
  user = "_argus"
  group = "_argus"
when "freebsd"
  package = "argus-sasl"
  config_dir = "/usr/local/etc"
when "ubuntu"
  default_group = "root"
  package = "argus-server"
when "redhat"
  default_group = "root"
end

log_owner = user
log_group = group
log_dir_owner = user
log_dir_group = group
config = "#{config_dir}/argus.conf"

describe package(package) do
  it { should be_installed }
end

extra_packages.each do |p|
  describe package p do
    it { should be_installed }
  end
end

describe group(group) do
  it { should exist }
end

describe user(user) do
  it { should belong_to_group group }
  extra_groups.each do |g|
    it { should belong_to_group g }
  end
end

describe file(config_dir) do
  it { should exist }
  it { should be_directory }
  it { should be_mode 755 }
  it { should be_owned_by default_user }
  it { should be_grouped_into default_group }
end

describe file(config) do
  it { should exist }
  it { should be_file }
  it { should be_mode config_mode }
  it { should be_owned_by user }
  it { should be_grouped_into group }
  its(:content) { should match(/Managed by ansible/) }
  its(:content) { should match(/ARGUS_INTERFACE=(?:em|eth)0/) }
end

describe file(log_dir) do
  it { should be_directory }
  it { should be_mode log_dir_mode }
  it { should be_owned_by log_dir_owner }
  it { should be_grouped_into log_dir_group }
end

case os[:family]
when "openbsd"
  describe file("/etc/rc.conf.local") do
    it { should be_file }
    it { should be_owned_by default_user }
    it { should be_grouped_into default_group }
    it { should be_mode 644 }
    its(:content) { should match(/^#{Regexp.escape("#{service}_flags=-F #{config}")}/) }
  end
when "redhat"
  describe file("/etc/sysconfig/#{service}") do
    it { should be_file }
    it { should be_mode 644 }
    it { should be_owned_by default_user }
    it { should be_grouped_into default_group }
    its(:content) { should match(/Managed by ansible/) }
  end

  describe file("/usr/lib/systemd/system/argus.service") do
    its(:content) { should match(Regexp.escape("ExecStart=/usr/sbin/argus $ARGUS_OPTIONS")) }
    its(:content) { should match(Regexp.escape("EnvironmentFile=-/etc/sysconfig/argus")) }
  end

  describe file("/usr/lib/sasl2") do
    it { should exist }
    it { should be_symlink }
    it { should be_linked_to "/usr/lib64/sasl2" }
  end
when "ubuntu"
  describe file("/lib/systemd/system/argus.service") do
    its(:content) { should match(Regexp.escape("ExecStart=/usr/sbin/argus $ARGUS_OPTIONS")) }
    its(:content) { should match(Regexp.escape("EnvironmentFile=-/etc/default/argus")) }
  end
  describe file("/etc/default/#{service}") do
    it { should be_file }
    it { should be_mode 644 }
    it { should be_owned_by default_user }
    it { should be_grouped_into default_group }
    its(:content) { should match(/Managed by ansible/) }
  end
when "freebsd"
  describe file("/etc/rc.conf.d") do
    it { should be_directory }
    it { should be_mode 755 }
    it { should be_owned_by default_user }
    it { should be_grouped_into default_group }
  end

  describe file("/etc/rc.conf.d/#{service}") do
    it { should be_file }
    it { should be_mode 644 }
    it { should be_owned_by default_user }
    it { should be_grouped_into default_group }
    its(:content) { should match(/Managed by ansible/) }
    its(:content) { should match(Regexp.escape("argus_flags='-F #{config}'")) }
  end
end

describe service(service) do
  it { should be_running }
  it { should be_enabled }
end

ports.each do |p|
  describe port(p) do
    it { should be_listening }
  end
end

describe file(log_file) do
  it { should be_file }
  it { should be_owned_by log_owner }
  it { should be_grouped_into log_group }
  it { should be_mode log_mode }
end
