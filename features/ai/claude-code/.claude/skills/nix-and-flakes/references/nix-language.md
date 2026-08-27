# Nix Language Reference

## Overview

Nix is a pure, lazy, functional language. Key characteristics:
- **Pure**: Functions have no side effects
- **Lazy**: Values computed only when needed
- **Functional**: Functions are first-class citizens

## Basic Types

```nix
# Strings
"hello world"
''
  Multi-line
  string
''
"interpolation: ${pkgs.hello}"

# Numbers
42
3.14

# Booleans
true
false

# Null
null

# Paths (NOT strings)
./relative/path
/absolute/path
~/home/path

# Lists
[ 1 2 3 "mixed" ./types ]

# Attribute Sets
{
  key = "value";
  nested.key = "works";
  "special-key" = "quoted";
}
```

## Attribute Sets

```nix
# Basic
let
  attrs = {
    a = 1;
    b = 2;
  };
in attrs.a  # => 1

# Recursive (rec)
rec {
  x = 1;
  y = x + 1;  # Can reference x
}

# Nested access
attrs.nested.deeply.value
attrs.nested.deeply.value or "default"  # with fallback

# Has attribute
attrs ? key  # => true/false

# Merge
attrs1 // attrs2  # attrs2 overrides attrs1
```

## Let Bindings

```nix
let
  x = 1;
  y = 2;
  f = a: a + 1;
in
  f x + y  # => 4
```

## Functions

```nix
# Single argument
x: x + 1

# Multiple arguments (curried)
x: y: x + y

# Attribute set argument
{ a, b }: a + b

# With defaults
{ a, b ? 0 }: a + b

# With extra attributes (@-pattern)
{ a, b, ... }@args: a + b + args.c

# Calling
(x: x + 1) 5  # => 6
(add 1) 2     # curried
func { a = 1; b = 2; }
```

## Control Flow

```nix
# If-then-else (expression, not statement!)
if x > 0 then "positive" else "non-positive"

# Assert
assert x > 0; x + 1  # fails if x <= 0

# With (brings attrs into scope)
with pkgs; [ git vim nodejs ]
# equivalent to: [ pkgs.git pkgs.vim pkgs.nodejs ]
```

## Inherit

```nix
# Shorthand for key = key
let
  x = 1;
  y = 2;
in {
  inherit x y;  # same as: x = x; y = y;
}

# From attribute set
{
  inherit (pkgs) git vim;  # same as: git = pkgs.git; vim = pkgs.vim;
}
```

## Import

```nix
# Import evaluates a Nix file
import ./file.nix

# Import with arguments
import ./file.nix { inherit pkgs; }

# Import directory (uses default.nix)
import ./directory
```

## Builtins

```nix
# Common builtins
builtins.toString 42            # "42"
builtins.toJSON { a = 1; }      # "{\"a\":1}"
builtins.fromJSON "{\"a\":1}"   # { a = 1; }
builtins.readFile ./file.txt    # file contents
builtins.pathExists ./path      # true/false
builtins.attrNames { a=1; b=2; } # [ "a" "b" ]
builtins.attrValues { a=1; b=2; } # [ 1 2 ]
builtins.map (x: x+1) [1 2 3]   # [ 2 3 4 ]
builtins.filter (x: x>1) [1 2 3] # [ 2 3 ]
builtins.elem 2 [1 2 3]         # true
builtins.length [1 2 3]         # 3
builtins.head [1 2 3]           # 1
builtins.tail [1 2 3]           # [ 2 3 ]
builtins.concatLists [[1] [2]]  # [ 1 2 ]
builtins.genList (i: i) 3       # [ 0 1 2 ]
builtins.listToAttrs [{name="a"; value=1;}]  # { a = 1; }
builtins.mapAttrs (n: v: v+1) {a=1;}  # { a = 2; }
builtins.fetchurl { url = "..."; sha256 = "..."; }
builtins.fetchGit { url = "..."; }
builtins.currentSystem          # "x86_64-linux" etc.
```

## Lib Functions

Common `nixpkgs.lib` functions:

```nix
{ lib, ... }: {
  # Conditionals
  lib.mkIf condition { /* config */ }
  lib.mkMerge [ config1 config2 ]

  # Priority
  lib.mkDefault value      # priority 1000
  lib.mkForce value        # priority 50
  lib.mkOverride 100 value # custom priority

  # List ordering
  lib.mkBefore list  # prepend
  lib.mkAfter list   # append

  # Options
  lib.mkOption { type = lib.types.str; default = ""; }
  lib.mkEnableOption "feature"

  # Strings
  lib.concatStrings [ "a" "b" ]        # "ab"
  lib.concatStringsSep ", " [ "a" "b" ] # "a, b"
  lib.optionalString true "yes"        # "yes"
  lib.strings.hasPrefix "foo" "foobar" # true

  # Lists
  lib.optional true "item"    # [ "item" ]
  lib.optionals true [ 1 2 ]  # [ 1 2 ]
  lib.flatten [ [1] [2 3] ]   # [ 1 2 3 ]
  lib.unique [ 1 1 2 ]        # [ 1 2 ]

  # Attrs
  lib.filterAttrs (n: v: v != null) attrs
  lib.mapAttrs (n: v: v + 1) attrs
  lib.recursiveUpdate attrs1 attrs2
  lib.attrByPath ["a" "b"] default attrs

  # Paths
  lib.makeLibraryPath [ pkgs.openssl ]
  lib.makeBinPath [ pkgs.git ]

  # System
  lib.systems.elaborate "x86_64-linux"
}
```

## Learning Resources

- **nix.dev** - Official learning resource: https://nix.dev
- **Tour of Nix** - Interactive tutorial: https://nixcloud.io/tour
- **Noogle.dev** - Function search engine: https://noogle.dev
- **Nix Pills** - Deep dive series: https://nixos.org/guides/nix-pills
- **Nix Reference Manual** - Official docs: https://nix.dev/manual/nix
