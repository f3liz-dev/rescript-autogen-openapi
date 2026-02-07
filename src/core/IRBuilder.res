// SPDX-License-Identifier: MPL-2.0

// IRBuilder.res - Fluent API for constructing IR types

// Constraint builders
module Constraints = {
  let string = (~min=?, ~max=?, ~pattern=?, ()) => {
    SchemaIR.minLength: min,
    maxLength: max,
    pattern,
  }

  let number = (~min=?, ~max=?, ~multipleOf=?, ()) => {
    SchemaIR.minimum: min,
    maximum: max,
    multipleOf,
  }

  let array = (~min=?, ~max=?, ~unique=false, ()) => {
    SchemaIR.minItems: min,
    maxItems: max,
    uniqueItems: unique,
  }
}

// Type builders
let string = (~min=?, ~max=?, ~pattern=?, ()) =>
  SchemaIR.String({constraints: Constraints.string(~min?, ~max?, ~pattern?, ())})

let number = (~min=?, ~max=?, ~multipleOf=?, ()) =>
  SchemaIR.Number({constraints: Constraints.number(~min?, ~max?, ~multipleOf?, ())})

let int = (~min=?, ~max=?, ~multipleOf=?, ()) =>
  SchemaIR.Integer({constraints: Constraints.number(~min?, ~max?, ~multipleOf?, ())})

let bool = SchemaIR.Boolean
let null = SchemaIR.Null
let unknown = SchemaIR.Unknown

let array = (~items, ~min=?, ~max=?, ~unique=false, ()) =>
  SchemaIR.Array({items, constraints: Constraints.array(~min?, ~max?, ~unique, ())})

let object_ = (~props, ~additional=?, ()) =>
  SchemaIR.Object({properties: props, additionalProperties: additional})

let union = types => SchemaIR.Union(types)
let intersection = types => SchemaIR.Intersection(types)
let ref = refPath => SchemaIR.Reference(refPath)
let option = type_ => SchemaIR.Option(type_)

// Literal builders
let stringLit = s => SchemaIR.Literal(StringLiteral(s))
let numberLit = n => SchemaIR.Literal(NumberLiteral(n))
let boolLit = b => SchemaIR.Literal(BooleanLiteral(b))
let nullLit = SchemaIR.Literal(NullLiteral)

// Property builder (name, type, required)
let prop = (name, type_, ~required=true, ()) => (name, type_, required)
let optProp = (name, type_) => (name, type_, false)

// Named schema builder
let named = (~name, ~description=?, type_) => {
  SchemaIR.name,
  description,
  type_,
}
