### Building OpenSSL for universal agents

To build OpenSSL for universal agents, we require building:

- OpenSSL 0.9.8
- OpenSSL 1.0.0

If you have write access to the MSFTOSSMgmt repositories, then you can
access [this repository] (https://github.com/MSFTOSSMgmt/openssl) for
easy access to these two versions of SSL.

If you do not have access to this repository, you can get the source code
from the [public repository] (https://github.com/openssl/openssl). Note
that we are after initial releases of OpenSSL 0.9.8 and OpenSSL 1.0.0
(no patches after those two versions).

#### Building SSL 0.9.8

Untar your distribution file, if necessary, and go into the base
directory of OpenSSL 0.9.8 with a command like:<br>```cd openssl-0.9.8```

Configure the software based on your build system:

- On a CentOS 6.x 64 bit OS, use ```./config no-asm -fPIC --prefix=/usr/local_ssl_0.9.8 shared```

- For all other platforms, use ```./config --prefix=/usr/local_ssl_0.9.8 shared```

After OpenSSL 0.9.8 is properly configured, use the standard mantra:

```
make
make test
sudo make install
```

Note that its normal to sometimes get unit test errors for SSL 0.9.8.
If that happens, just proceed to 'sudo make install'.

#### Building SSL 1.0.0

Untar your distribution file, if necessary, and go into the base
directory of OpenSSL 1.0.0 with a command like:<br>```cd openssl-1.0.0```

To configure and build SSL 1.0.0, use the following commands:

```
./config --prefix=/usr/local_ssl_1.0.0 shared -no-ssl2 -no-ec -no-ec2m -no-ecdh
make depend
make
make test
sudo make install_sw
```

Unlike SSL 0.9.8, we've never seen unit test failures for SSL 1.0.0.

Notes for SSL configuration:

- Note: https://stackoverflow.com/questions/8206546/undefined-symbol-sslv2-method discusses why the -no-ssl2 qualifier is now required for compatibility with newer Ubuntu systems, depending on APIs utilized by the SSL client.

- https://stackoverflow.com/questions/22311699/trouble-with-openssl-on-rhel-6-3-and-all-ruby-installers describes why we need to specify the -no-ec2m flag.

### Closing notes

We need these installed ONLY on ULinux build systems
(i.e. CentOS 32-bit and 64-bit, depending on the product(s) involved).
No other systems need these kits.

Note that the ./config line utilize the --prefix option. The directory
paths for the prefix (```/usr/local_ssl_0.9.8``` and
```/usr/local_ssl_1.0.0```) are hard-coded in our make process.  You can't
change that without careful consideration, as it would impact the build
procedures for numerous projects.

Finally, note that these bits are both installed <b>regardless</b> of the
version of SSL installed on the system. Furthermore, nothing (other than
our kit) links against these. No system software uses the SSL versions
in these locations.
