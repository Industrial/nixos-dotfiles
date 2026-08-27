# Advanced MVU Forms — Parameterization, Monads, and State Machines

When building complex forms (10+ fields) in Lustre, standard MVU boilerplate explodes. To keep the `update` function maintainable and prevent impossible states, employ the following advanced MVU patterns.

## 1. Parameterized Messages (Typed Discriminants)

Instead of creating one `Msg` variant per field, group events by their domain and use typed discriminants.

**BAD (Msg Explosion):**
```gleam
pub type Msg {
  UserTypedCep(String)
  UserTypedStreet(String)
  UserTypedCity(String)
  UserBlurredCep
  // ... 20 more variants
}
```

**GOOD (Parameterized):**
```gleam
pub type AddressFormField {
  AddressFormFieldCep
  AddressFormFieldStreet
  AddressFormFieldCity
}

pub type Msg {
  UserTypedAddressField(field: AddressFormField, value: String)
  UserBlurredAddressField(field: AddressFormField)
}
```

*Benefit:* The `update` function collapses from 20 branches into 2. A single helper `set_address_field(form, field, value) -> Form` handles all typing logic exhaustively.

---

## 2. Monadic Request Building (`use` syntax)

Building API requests from validated fields requires unpacking `Option` or `Result` types. Do not use giant tuples in `case` statements (Pyramids of Doom). Use Gleam's `use` syntax with `result.try` or `option.then`.

**BAD:**
```gleam
case validate_email(f.email), validate_cpf(f.cpf), validate_name(f.name) {
  Ok(e), Ok(c), Ok(n) -> Ok(Request(e, c, n))
  _, _, _ -> Error(Nil) // Fails to scale past 3 fields
}
```

**GOOD:**
```gleam
import gleam/option
import gleam/result

fn build_request(form: Form) -> Result(UpdateAddressRequest, Nil) {
  // Required fields: short-circuits to Error if any value is missing
  use parsed_street <- result.try(field_state.value(form.street) |> option.to_result(Nil))
  use parsed_cep <- result.try(field_state.value(form.cep) |> option.to_result(Nil))
  
  // Optional fields: extract safely without short-circuiting
  let parsed_number = option.flatten(field_state.value(form.number))

  Ok(customer.UpdateAddressRequest(
    street: parsed_street,
    cep: parsed_cep,
    number: parsed_number,
  ))
}
```

---

## 3. Form-Level State Machines

A form's **save lifecycle** is a state machine: it is either `SubmitIdle` (editable), `SubmitSaving` (locked, in flight), `SubmitSaved` (done), or `SubmitFailed(ErrorCode)` (editable again, showing the server error). The model **owns its form-data record** and carries a *sibling* `save` field holding that lifecycle. The **variant is the flag** — the saving status is never a `Bool`.

**BAD (the "boolean twin"):**
```gleam
pub type CustomerDialog {
  CustomerDialog(
    data: CustomerFormData,
    saving: Bool,              // detached! user can type while saving
    error: Option(ErrorCode),  // 8 representable states, most invalid:
  )                            // saving=True AND error=Some AND already saved?
}
```

A `Bool` + `Option` pair encodes impossible combinations and lets edits land mid-flight.

**GOOD (sibling save-lifecycle field):**
The model owns its data; one sibling `save` field carries the whole lifecycle as a sum type.

```gleam
pub type Submit {
  SubmitIdle
  SubmitSaving
  SubmitSaved
  SubmitFailed(ErrorCode)  // the typed error channel — see error-handling.md
}

pub type CustomerDialog {
  CustomerDialog(
    data: CustomerFormData,  // the model owns its form-data record
    save: Submit,            // the whole save lifecycle in one field
  )
}
```

*Benefit:*
1. **Updates:** In `update.gleam`, a `UserTyped…` message that arrives while the save is in flight is simply dropped — no edit lands mid-flight. Guard **behaviorally** with a predicate, never by hard-coding a stored `Bool`.
2. **Views:** In `view.gleam`, predicates (`submit.is_saving`, `submit.is_failed`) drive `disabled:` on every input and surface the `SubmitFailed(ErrorCode)` payload as the form-level error.

Guard on **behavior**, not structure:
```gleam
// view.gleam — disable inputs while the save is in flight
let locked = submit.is_saving(model.save)
html.input([attribute.disabled(locked), ..attrs])

// update.gleam — ignore edits during flight
case submit.is_saving(model.save) {
  True -> #(model, effect.none())                       // drop the edit
  False -> #(set_field(model, field, value), effect.none())
}
```

**Page loads work the same way.** Model an async page payload as `RemoteData` — the loaded value lives *inside* the `RemoteLoaded` variant — and guard with `remote.is_loading`, never an `is_loading: Bool` beside an `Option(data)`. (See `RemoteData` in `gleam/references/fundamentals/type-design.md`.)

> **aboio reference implementation — the `spine` lib.** In the aboio house stack, `Submit` and `RemoteData` ship in the vendored `spine` lib, each re-bound in the client as an `ErrorCode`-specialized type alias (`state/submit`, `state/remote`). The pattern above is what matters — if your project doesn't vendor `spine`, define the equivalent unions yourself.
>
> **Import recipe (aboio stack).** The `state/*` modules expose only the **type aliases** (`type Submit`, `type RemoteData`); the **constructors and predicates** (`SubmitSaving`, `submit.is_saving`, `remote.is_loading`) live in `spine/submit` / `spine/remote`. The two `submit` modules collide on the bare name, so a file that *both* annotates a field and calls predicates needs:
> ```gleam
> import spine/submit                   // constructors + predicates: submit.SubmitSaving, submit.is_saving
> import state/submit as state_submit   // the ErrorCode-bound alias, for annotations only
> ```
> A model-type file that only annotates can use `import state/submit.{type Submit}` alone.

---

## 4. Avoiding Boolean Blindness in Forms

When form logic splits paths (e.g. "billing address same as delivery"), do not use `Bool`. Use explicit Sum Types.

**BAD:**
```gleam
billing: AddressForm,
billing_same_as_delivery: Bool,
```

**GOOD:**
```gleam
pub type BillingAddressMode {
  BillingAddressModeSameAsDelivery
  BillingAddressModeSeparate(form: AddressForm)
}
```

*Benefit:* Eliminates "zombie state" (where a boolean is true, but a stale hidden address form still lingers in the background, validating errors invisibly).