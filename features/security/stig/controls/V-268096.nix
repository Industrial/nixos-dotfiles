# V-268096 (CAT II) — Successful/unsuccessful uses of init_module, finit_module and
# delete_module must generate an audit record.
#
# Rules transcribed from the fix text.
{...}: {
  security.audit.rules = [
    "-a always,exit -F arch=b32 -S init_module,finit_module,delete_module -F auid>=1000 -F auid!=unset -k module_chng"
    "-a always,exit -F arch=b64 -S init_module,finit_module,delete_module -F auid>=1000 -F auid!=unset -k module_chng"
  ];
}
