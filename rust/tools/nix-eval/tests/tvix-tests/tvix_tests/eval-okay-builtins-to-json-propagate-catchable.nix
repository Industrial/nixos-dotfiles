map (e: (builtins.tryEval (builtins.toJSON e)).success) [
  (builtins.throw "a")
  {
    a = builtins.throw "attribute a";
  }
  {
    a.b.c.d.e.f.g.h.i = builtins.throw "deep i";
  }
  {
    x = 32;
    y = builtins.throw "second argument";
  }
  {
    __toString = _: builtins.throw "__toString a";
  }
  # FIXME(raitobezarius): we would like to test coercions, i.e. `toFile` and `derivation` containing throwables.
]
