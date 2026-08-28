# modules/ — the execution layer

These 45 Terraform modules realize the YAML document families. They are
called by `stacks/<stage>/` — never directly by an environment — and the
**authoring contract is `schemas/`** (browsable at
`knowledge-base/schema-viewer/`): every field a document may carry is
defined there, validated by `tools/validate/validate.py`, and mirrored
into a typed stack variable before it reaches a module. Typed variables
silently drop unmirrored attributes, so a capability that needs a new
field starts at the schema, not here — follow
`knowledge-base/CONTRIBUTING.md` (schema → typed variable → module).

Per-module READMEs are deliberately absent: the document grammar is the
interface, and it lives in the schemas. The exception pattern is
`quota_preference/`, whose README documents a module that is ALSO usable
standalone.
