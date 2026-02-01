let
  # makes the two sets have different capacity internally
  a = {
    a = 1;
    b = 2;
    c = 3;
    d = 4;
    e = 5;
  };
  b =
    {
      a = 1;
      b = 2;
      c = 3;
    }
    // {
      d = 4;
      e = 5;
    };

  nested1 = {
    foo = {
      bar = "bar";
    };
    b = 1;
  };

  nested2 = {
    foo.bar = "bar";
    b = 1;
  };

in
[
  (
    {
      foo = "foo";
      bar = 10;
    } == {
      bar = 10;
      foo = "foo";
    }
  )
  (a == b)
  (nested1 == nested2)
  # just so theres a negativ case
  (a == nested1)
]
