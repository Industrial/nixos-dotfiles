# V-268129 (CAT II) — NixOS must require the change of at least 50 percent of the total number
# of characters when passwords are changed.
#
# Fix text: difok=8.
#
# Note the arithmetic only works alongside V-268134's 15-character minimum, which lives in the
# full profile: 8 changed characters is "at least 50 percent" of a 15-character password. On a
# host without the length minimum, difok=8 is an absolute count rather than a percentage, so
# this control is weaker in base-safe than the requirement's wording implies. Recorded for the
# report's justification column.
#
# Contributed through `security.stig.pwquality`; see that option's description.
{...}: {
  security.stig.pwquality.difok = 8;
}
