# Burrito Selective NIF Skip Patch

## Problem

Burrito 1.5.0 only supports `skip_nifs: true` (skip ALL NIFs) or `skip_nifs: false` (recompile ALL NIFs). This is problematic when you need to:
- Use precompiled NIFs for some dependencies (e.g., vix with bundled libvips for portability)
- Still allow Burrito to cross-compile other NIFs (e.g., exqlite, bcrypt_elixir)

## Solution

This patch modifies `lib/steps/patch/recompile_nifs.ex` to support `skip_nifs` as a list of atoms, enabling selective NIF recompilation control.

## Usage

### Before (Burrito 1.5.0)
```elixir
# In mix.exs
burrito: [
  targets: [
    linux_x86: [
      os: :linux,
      cpu: :x86_64,
      skip_nifs: true  # Skips ALL NIFs - breaks exqlite, bcrypt, etc.
    ]
  ]
]
```

### After (With Patch)
```elixir
# In mix.exs
burrito: [
  targets: [
    linux_x86: [
      os: :linux,
      cpu: :x86_64,
      skip_nifs: [:vix, :html5ever]  # Skips ONLY these NIFs, recompiles others
    ]
  ]
]
```

## Supported Formats

After applying this patch, `skip_nifs` accepts:
- `false` - Recompile all NIFs (default behavior)
- `true` - Skip all NIFs (original behavior)
- `[:atom1, :atom2]` - Skip only specified NIFs, recompile others (NEW!)

## Application

### Method 1: Git Patch
```bash
cd /path/to/burrito
git apply burrito_selective_nif_skip.patch
```

### Method 2: Manual Edit
Edit `lib/steps/patch/recompile_nifs.ex` in your Burrito installation and replace the `execute/1` function as shown in the patch.

### Method 3: Use Modified Burrito as Path Dependency
```elixir
# In mix.exs
{:burrito, path: "/path/to/modified/burrito"}
```

## Real-World Example: Vix with Precompiled libvips

### Problem Context
- Vix provides precompiled NIFs with bundled libvips for portability
- Burrito's cross-compilation deletes these precompiled binaries and attempts recompilation
- Recompilation requires system libvips-dev, defeating portability

### Solution
1. Install precompiled vix before building:
   ```bash
   ./install_vix_precompiled.sh  # Downloads from github.com/akash-akya/vix releases
   ```

2. Configure Burrito to skip vix recompilation:
   ```elixir
   burrito: [
     targets: [
       linux_x86: [
         os: :linux,
         cpu: :x86_64,
         skip_nifs: [:vix, :html5ever]
       ]
     ]
   ]
   ```

3. Build with Burrito:
   ```bash
   mix release
   ```

Result: Portable binary with vix's bundled libvips works on ANY x86_64 Linux system!

## Technical Details

### Changed Behavior
**File:** `lib/steps/patch/recompile_nifs.ex`  
**Function:** `execute/1`

**Before:**
```elixir
skip_nifs? = Keyword.get(context.target.qualifiers, :skip_nifs, false)

if context.target.cross_build and not skip_nifs? do
  nif_sniff()
  |> Enum.each(fn dep ->
    maybe_recompile_nif(dep, ...)
  end)
end
```

**After:**
```elixir
skip_nifs_config = Keyword.get(context.target.qualifiers, :skip_nifs, false)

skip_nifs_list = case skip_nifs_config do
  true -> :all
  false -> []
  list when is_list(list) -> list
  _ -> []
end

if context.target.cross_build and skip_nifs_list != :all do
  nif_sniff()
  |> Enum.each(fn dep ->
    should_skip = skip_nifs_list == :all or (elem(dep, 0) in skip_nifs_list)
    
    unless should_skip do
      maybe_recompile_nif(dep, ...)
    end
  end)
end
```

### Backward Compatibility
✅ **Fully backward compatible!**
- `skip_nifs: false` - Works as before (recompile all)
- `skip_nifs: true` - Works as before (skip all)
- `skip_nifs: [:vix]` - NEW feature (skip specific)

## Testing

After applying the patch:

1. Configure selective NIF skipping in `mix.exs`
2. Install precompiled NIFs you want to preserve
3. Run `MIX_ENV=prod mix release`
4. Verify build output:
   - Should see "Going to recompile NIF" for non-skipped NIFs (exqlite, bcrypt)
   - Should NOT see recompilation messages for skipped NIFs (vix, html5ever)

## Why This Matters

### Portability
Precompiled NIFs with bundled native libraries (like vix's libvips) enable true portability:
- ✅ Binary works on ANY x86_64 Linux (Ubuntu, Fedora, Debian, Alpine, etc.)
- ✅ No system dependencies required on target machine
- ✅ No "library not found" errors

### Sustainability
Without this patch, you'd need hacky workarounds:
- ❌ Manually copying precompiled NIFs after Burrito deletes them
- ❌ Patching Burrito's NIF detection to not detect certain packages
- ❌ Using `skip_nifs: true` and manually managing ALL NIFs

## License

This patch is provided as-is for the Burrito project (MIT License).

## Related Issues

This solves problems when:
- Using vix (Elixir libvips bindings) with Burrito
- Using rust NIFs that provide precompiled binaries
- Targeting systems without dev libraries installed
- Creating truly portable standalone Elixir applications

## Credits

Created: November 4, 2025  
Context: Building portable Silicon Brain releases with vix image processing  
Problem: Burrito deleted precompiled vix with bundled libvips during cross-compilation  
Solution: Enable selective NIF skip to preserve portable precompiled binaries
