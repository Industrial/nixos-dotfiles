# The 'namespace' of a with should only be evaluated if an identifier
# from it is actually accessed.
with (abort "should not be evaluated"); 42
