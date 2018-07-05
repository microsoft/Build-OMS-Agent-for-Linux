# Operations Management Suite Linux Agent

## Table of Contents
- [Setting up a machine to build OMS](#setting-up-a-machine-to-build-oms)
  - [Sudoers configuration](#sudoers-configuration)
  - [Dependencies to build a native package](#dependencies-to-build-a-native-package)
  - [Setting up a system to build a shell bundle](#setting-up-a-system-to-build-a-shell-bundle)
- [Cloning the repositories](#cloning-the-repositories)
- [Preparing system tests](#preparing-system-tests)
- [Building omsagent](#building-omsagent)
- [Troubleshooting](#troubleshooting)
- [Code of Conduct](#code-of-conduct)

If you are an active contributor to the OMS-Agent project, you should
[set up your system](https://github.com/Microsoft/ostc-docs/blob/master/setup-git.md)
and follow our [common workflow](https://github.com/Microsoft/ostc-docs/blob/master/workflow-workflow.md).
New to git? Read [guidelines for development](https://github.com/Microsoft/ostc-docs/blob/master/setup-rules.md).

-----

### Setting up a machine to build OMS

A "shell bundle" is a distribution mechanism for the OMS agent. A shell
bundle is a shell script that has, as part of it, .RPM and .DEB native
package files. The shell bundle determines what has to be installed based
on system configuration and installs the appropriate packages.

There are two ways to build OMS.

1. As an RPM or DEB package that can be installed on the local system,
assuming all dependencies are met (most easily met if a shell bundle
was previously installed to "seed" the system), or

2. As a shell bundle.

Building a shell bundle is a superset of of setting up a system to
build a local RPM, so we will cover that first.

#### Sudoers configuration

[Configure sudo](https://github.com/Microsoft/ostc-docs/blob/master/setup-build.md)

#### Dependencies to build a native package

Note that it's very nice to be able to use the [updatedns](https://github.com/jeffaco/msft-updatedns) project to use host names
rather than IP numbers in a Hyper-V environment. On CentOS systems,
this requires the bind-utils package (updatedns requires the 'dig'
program). The bind-utils package isn't otherwise necessary.

- On CentOS 7.x
```
 sudo yum install git bind-utils bison gcc-c++ rpm-devel pam-devel openssl-devel rpm-build mysql-devel cmake boost-devel boost-test audit-libs-devel unzip
```
- On Ubuntu 14.04
```
 sudo apt-get install git pkg-config make bison g++ rpm librpm-dev libpam0g-dev libssl-dev libmysqlclient-dev cmake libboost-dev libboost-test-dev libaudit-dev libauparse-dev unzip
```
Install minimum version of Ruby (the system must have 1.9 or higher, but 2.2.6 is recommended). This is needed for all systems. This can be done with the following commands:
```
 wget https://cache.ruby-lang.org/pub/ruby/2.2/ruby-2.2.6.tar.gz
 tar xzvf ruby-2.2.6.tar.gz
 cd ruby-2.2.6
 ./configure
 make
 sudo make install
 $(which ruby) --version  # verify that this prints 2.2.6
```

- Note on libboost

Libboost is not a runtime dependency. It is only needed to build and run the OMS-Auditd-Plugin unittests.

- Notes on other platforms

 When building a machine for ULINUX builds (such as CentOS 5.x), we suggest
 using the O/S distribution CD to install the packages. It's not as easy,
 but that's the only way to guarentee that packages aren't updated such that
 generated binaries are not backwards compatible. (See notes on building a
 shell bundle, elsewhere in this document.)

 Also note that since you won't use 'yum', you must also handle the dependent
 packages manually (keep adding lines to the 'rpm install' command line until
 all dependencies are satisfied).

 Similar methods would be utilized if building a Redhat system that is not
 registered for use for up2date.

#### Setting up a system to build a shell bundle

To build a shell bundle, we need and older Linux system (we typically use
CentOS 5.0 for this), as binary images created with older Linux systems
are generally upwards compatible when installed on newer Linux systems.

A notable exception: We use the OpenSSL package, and we can't tell if
we need OpenSSL v1.0.x or OpenSSL v1.1.x. As a result, we have a [special
process](https://github.com/Microsoft/ostc-openssl/blob/master/README.md)
to build both both versions of OpenSSL that we can link against.

Once OpenSSL is set up, you need to configure omsagent to include the
```--enable-ulinux``` qualifier, like this:<br>```./configure --enable-ulinux``` 

### Cloning the repositories

If you have read access to the [OMS TestConfig](https://github.com/Microsoft/OMS-Agent-for-Linux-testconfig) project,
use the following.

Otherwise, only run the first `git clone` command and refer to 
[preparing system tests](#preparing-system-tests) if you want them to be run.

```shell
git clone --recursive git@github.com:Microsoft/Build-OMS-Agent-for-Linux.git bld-omsagent
git clone git@github.com:Microsoft/OMS-Agent-for-Linux-testconfig.git bld-omsagent/omsagent/test/config
```

Note that there are several subprojects, and authentication is a hassle
unless you set up an SSH key via your GitHub account. [Set up your machine]
(https://github.com/Microsoft/ostc-docs/blob/master/setup-git.md)
properly for a much easier workflow.

#### Preparing system tests

**This section only aplies if you do not have read access to [OMS TestConfig](https://github.com/Microsoft/OMS-Agent-for-Linux-testconfig) project**

System tests communicate with the server. They require keys which may
not be published.  You may obtain your own keys for free by creating
an account on [Microsoft Operations Management
Suite](http://www.microsoft.com/en-us/server-cloud/operations-management-suite/why-oms.aspx)
then get the keys from the settings view.

Create the file `bld-omsagent/omsagent/test/config/systest.conf`
with content like so:
``` shell
export TEST_WORKSPACE_ID=<id>
export TEST_SHARED_KEY=<key>

export TEST_WORKSPACE_ID_2=<id>
export TEST_SHARED_KEY_2=<key>

export TEST_PROXY_SETTING="http://proxyuser:proxypass@host:8080"
```

### Building omsagent

From the bld-omsagent directory (created above from 'git clone', do the
following:

```
cd omsagent/build
./configure
make
make test
```

Note that the ```configure``` script takes a variety of options. You can
use ```configure --help``` to see the options available.

When the build completes, you should have a native package that you can install
on your system. The native package should be in a subdirectory off of
bld-omsagent/omsagent/target (the directory name varies based on debug vs.
release builds).

As mentioned above, this form of build requires a shell bundle to be installed
to "seed" your system with other required dependencies.

Note that the build will build multiple versions of Ruby (one for unit test,
only built once, even after "make distclean"), and then one or two versions
depending if you're building for a shell bundle or not. Bottom line: The
first build is always slower than subsequent builds.

### Troubleshooting

#### Improper clone of project

If you get an error during the Ruby build like:
```
downloader.rb:180: private method `class_variable_set' called for Downloader:Class (NoMethodError)
configure: error: cannot run /bin/sh tool/config.sub
make: *** [/usr/local/ruby-2.2.0a] Error 127
```
While this points to an issue where your system version of Ruby is too old
(strangely enough, Ruby is required to build Ruby), the root source of the
issue is that you didn't clone the repository recursively. Please read
[the section on cloning the repositories](#cloning-the-repositories) for
details on how to clone the repository.

### Code of Conduct

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).  For more
information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact
[opencode@microsoft.com](mailto:opencode@microsoft.com) with any
additional questions or comments.
