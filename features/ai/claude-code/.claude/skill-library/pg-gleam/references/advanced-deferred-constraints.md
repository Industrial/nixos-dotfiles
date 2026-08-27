---
title: Use Deferred Constraints for Complex Business Rules
impact: MEDIUM
impactDescription: Enables multi-statement validation within a transaction
tags: constraints, deferred, triggers, transactions
---

## Use Deferred Constraints for Complex Business Rules

Use `DEFERRABLE INITIALLY DEFERRED` constraint triggers when validation requires seeing the final state of multiple related rows within a transaction.

**Use case: double-entry accounting balance validation**

Each journal entry must have balanced debits and credits, but individual rows are inserted one at a time.

**Incorrect (immediate constraint):**

```sql
-- This can't work: each row is validated individually
-- The first debit row has no matching credit yet
alter table tenant.journal_entry
  add constraint chk_balanced check (/* can't check across rows */);
```

**Correct (deferred constraint trigger):**

```sql
-- Validation function: check that debits = credits for each transaction
create or replace function tenant.validate_journal_balance()
returns trigger
language plpgsql
as $$
declare
  v_balance bigint;
begin
  select sum(case when entry_type = 'debit' then amount else -amount end)
  into v_balance
  from tenant.journal_entry
  where transaction_id = new.transaction_id;

  if v_balance != 0 then
    raise exception 'Journal entries for transaction % are not balanced (off by %)',
      new.transaction_id, v_balance;
  end if;

  return new;
end;
$$;

-- Create constraint trigger that runs at COMMIT time
create constraint trigger trg_validate_journal_balance
  after insert or update on tenant.journal_entry
  deferrable initially deferred
  for each row
  execute function tenant.validate_journal_balance();
```

**Usage within a transaction:**

```sql
begin;
  -- Insert debit entry (unbalanced at this point - that's ok)
  insert into tenant.journal_entry (transaction_id, account_id, entry_type, amount)
  values ('txn-001', 'cash-acct', 'debit', 1000000);

  -- Insert credit entry (now balanced)
  insert into tenant.journal_entry (transaction_id, account_id, entry_type, amount)
  values ('txn-001', 'revenue-acct', 'credit', 1000000);
commit;
-- Trigger fires at COMMIT: validates balance, succeeds

begin;
  insert into tenant.journal_entry (transaction_id, account_id, entry_type, amount)
  values ('txn-002', 'cash-acct', 'debit', 500000);
commit;
-- Trigger fires at COMMIT: unbalanced! Transaction rolls back
```

When to use deferred vs immediate constraints:

- **Immediate**: Single-row validation, simple FK checks, not-null
- **Deferred**: Cross-row validation within a transaction, circular FKs, batch consistency

Reference: [Constraint Triggers](https://www.postgresql.org/docs/current/sql-createtrigger.html)
