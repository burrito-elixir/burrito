# Burrito Examples

This directory contains a few sample applications that demonstrate the capabilities of Burrito!

## cli_example
----

A simple application that prints a random number and the arguments passed to it to standard out. **Supports all platforms.**


## only_one
----

A simple CLI application that demonstrates Zig plugins, it will not allow more than 1 copy of the application to run at a time.
It utilizes a lockfile, and a NIF to catch SIGINT for proper lockfile cleanup. **Windows not supported currently.**

## phx_app
----

A simple Phoenix app with os_mon enabled. Created with: `mix phx.new phx_app --no-mailer --no-tailwind --database=sqlite3`.
**Supports all platforms.**