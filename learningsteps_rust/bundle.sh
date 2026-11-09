#!/bin/bash

# Check if cargo and rustc is installed and install theme based on the OS (Windows needs a propper exit 1 with information: "See: https://rust-lang.org/tools/install/").
# Ubuntu/Debiant: https://doc.rust-lang.org/book/ch01-01-installation.html#installing-rustup-on-linux-or-macos
# Windows: https://doc.rust-lang.org/book/ch01-01-installation.html#installing-rustup-on-windows
# MacOS: https://doc.rust-lang.org/book/ch01-01-installation.html#installing-rustup-on-linux-or-macos
# Windows WSL: `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`

# Build bin
cargo build

# copy bin to /usr/bin/
cp ./target/build/lsteps /usr/bin/lsteps

# Verify copy successed

# Verify lsteps is available
which lsteps