# 🌯 Changelog

## v1.4.0

* Changes:
  * Add `CHANGELOG.md` (yay!).
  * Remove fixed OpenSSL version tag from pre-build URL fetching modules.
  * Allow overriding the cookie with `RELEASE_COOKIE` at runtime.
  * Move `seven_z` check under `target.os` `:windows`.
  * Bump zig to `0.14.1`.
  * Fixed compiler warning in `module.project()` call.
  * Remove deprecated `File.cp_r/3` usage in init step.
  * Bump erlang to `28.0.2` and elixir to `1.18.4-otp-28`.
  * Pre-Built ERTSs will now contain OpenSSL `3.5.1` and musl libc `1.2.5`.

## v1.3.0

* Changes:
  * Use `7zz` CLI tool for unpacking Windows ERTS installers if available.
  * Dependency bumps:
    * erlang `27.2`
    * elixir `1.18.1-otp-27`
    * req `>= 0.5.0`
    * jason `~> 1.4`
    * zig `1.14.0`
  * Fix broken `7z`/`7zz` check.

## v1.2.0

* Changes:
  * README fixups.
  * Add utility function to fetch wrapper exe path at runtime. (`Burrito.Util.Args.get_bin_path/0`)

## v1.1.1

* Changes:
  * Release version requirement for Req library (`>= 0.4.0`).

## v1.1.0

* Changes:
  * Add `Burrito.Util.running_standalone`.
  * Add `Burrito.Util.Args.argv` to get arguments universally.
  * Fix crash when fetching a custom ERTS build from a URL string location.
  * README fix: Fix dead link to Erlang Embedded Mode docs.
  * Bump Zig to `0.13.0`.

## v1.0.5

* Changes:
  * Better handle files in the root of a release.
  * Update Zig wrappers path computation to be more cross-platform native.
  * Remove dead code from the Zig wrapper.
  * Fix trying to re-extract the libc musl `.so` file when it already exists.
  * Set up CI using Github Actions to validate cross builds and test examples.

## v1.0.4

* Changes
  * Fix not setting `__BURRITO` env variable in Windows executables.

## v1.0.3

* Changes:
  * Add qualifiers to targets to add CFLAGS, CXXFLAGS, ENV, and Make args to NIF re-compiler.
  * Add runtime env variable __BURRITO to signify erlang is running in Burrito.
  * Allow skipping NIF recompilation with build qualifier. (`:skip_nifs`)
  * Add new qualifiers to README.

## v1.0.2

* Changes:
  * Include the version file in releases.
  * Bump req to `0.4.0`.
  * Bump deps in example projects.

## v1.0.1

* Changes:
  * Fix Hex package include files.

## v1.0.0 

* Changes:
  * Initial Release