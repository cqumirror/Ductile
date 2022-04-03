 # Options

| short option | long option | description                                                  | variable or function | need arguement       | Remarks                                                |
| ------------ | ----------- | ------------------------------------------------------------ | -------------------- | -------------------- | ------------------------------------------------------ |
| v            | version     | Get version of this scripts..                                | version()            | No                   |                                                        |
| m            | mirror      | Specific a mirror to use.                                    | MIRROR               | Yes                  | get mirror list from file or mirrorz.org?              |
| h            | help        | Show help information and exit.                              | usage()              | No(But Yes actually) |                                                        |
| c            | config      | Read file from config file.                                  |                      | Yes                  |                                                        |
| R            | refresh     | Automatically refresh repo database.                         |                      | No                   |                                                        |
| V            | verbose     | Dry run this scripts and show things to change without applying changes. |                      | No                   |                                                        |
| r            | recommand   | Add recommanded repos like `archlinuxcn` for Arch Linux.     |                      | No                   |                                                        |
| p            | pm          | Specify the package manager individually.                    |                      | Yes                  | may not be implemented                                 |
| i            | ask         | Run interactively.                                           |                      | No                   |                                                        |
| U            | offline     | Run scritps offline. Require `MIRROR` to be set.             |                      | No                   | `MIRROR` must be set                                   |
| S            | speed       | Run mirror speedtest and choose the fastest one.             |                      | No                   | may not be implemented or may be the last to implement |
