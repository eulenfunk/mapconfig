## Eulenmap setup

Before running gen.sh, make sure fastd (and tunneldigger for l2tp domains) are installed.
You can get tunneldigger from [this repository](https://github.com/wlanslovenija/tunneldigger). Check out the master branch, install the following build dependencies (ubuntu/debian package names):

```
$ sudo apt install -y build-essential cmake pkg-config libnl-3-dev
$ git clone https://github.com/wlanslovenija/tunneldigger
$ cd tunneldigger
$ mkdir build
$ cd build
$ cmake ../client
$ make
$ sudo make install
```
