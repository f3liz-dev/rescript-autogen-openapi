// SPDX-License-Identifier: MPL-2.0

// SchemaIR.res - Unified Intermediate Representation for JSON Schema
// This IR abstracts away JSON Schema details and provides a clean representation
// that can be used to generate both ReScript types and Sury schemas

// Validation constraints
type stringConstraints = {
  minLength: option<int>,
  maxLength: option<int>,
  pattern: option<string>,
}

type numberConstraints = {
  minimum: option<float>,
  maximum: option<float>,
  multipleOf: option<float>,
}

type arrayConstraints = {
  minItems: option<int>,
  maxItems: option<int>,
  uniqueItems: bool,
}

// Core IR types
type rec irType =
  | String({constraints: stringConstraints})
  | Number({constraints: numberConstraints})
  | Integer({constraints: numberConstraints})
  | Boolean
  | Null
  | Array({items: irType, constraints: arrayConstraints})
  | Object({
      properties: array<(string, irType, bool)>, // (name, type, required)
      additionalProperties: option<irType>,
    })
  | Literal(literalValue)
  | Union(array<irType>)
  | Intersection(array<irType>)
  | Reference(string) // Schema reference like "#/components/schemas/User"
  | Option(irType) // Nullable/optional types
  | Unknown

and literalValue =
  | StringLiteral(string)
  | NumberLiteral(float)
  | BooleanLiteral(bool)
  | NullLiteral

// Named schema definition
type namedSchema = {
  name: string,
  description: option<string>,
  type_: irType,
}

// Schema context for resolving references
type schemaContext = {
  schemas: Dict.t<namedSchema>,
}

// Helpers
let isOptional = (irType: irType): bool => {
  switch irType {
  | Option(_) => true
  | _ => false
  }
}

let unwrapOption = (irType: irType): irType => {
  switch irType {
  | Option(inner) => inner
  | other => other
  }
}

let makeOptional = (irType: irType): irType => {
  switch irType {
  | Option(_) => irType // Already optional
  | other => Option(other)
  }
}

// Check if a type is simple (no complex nested structures)
let rec isSimpleType = (irType: irType): bool => {
  switch irType {
  | String(_) | Number(_) | Integer(_) | Boolean | Null | Reference(_) => true
  | Option(inner) => isSimpleType(inner)
  | Literal(_) => true
  | Array({items, _}) => isSimpleType(items)
  | Object(_) | Union(_) | Intersection(_) | Unknown => false
  }
}

// Count the complexity of a type (for deciding whether to inline or extract)
let rec complexityScore = (irType: irType): int => {
  switch irType {
  | String(_) | Number(_) | Integer(_) | Boolean | Null | Reference(_) | Literal(_) => 1
  | Option(inner) => complexityScore(inner)
  | Array({items, _}) => 1 + complexityScore(items)
  | Object({properties, _}) => {
      let propsScore = properties
        ->Array.map(((_, type_, _)) => complexityScore(type_))
        ->Array.reduce(0, (acc, score) => acc + score)
      5 + propsScore // Objects are inherently complex
    }
  | Union(types) => {
      let typesScore = types
        ->Array.map(complexityScore)
        ->Array.reduce(0, (acc, score) => acc + score)
      2 + typesScore
    }
  | Intersection(types) => {
      let typesScore = types
        ->Array.map(complexityScore)
        ->Array.reduce(0, (acc, score) => acc + score)
      3 + typesScore
    }
  | Unknown => 1
  }
}

// Extract nested complex types that should be named separately
// Returns (simplified type, extracted schemas)
let rec extractComplexTypes = (
  ~baseName: string,
  ~irType: irType,
  ~threshold: int=10,
): (irType, array<namedSchema>) => {
  let score = complexityScore(irType)
  
  if score <= threshold {
    (irType, [])
  } else {
    switch irType {
    | Object({properties, additionalProperties}) => {
        // Extract complex property types
        let (newProperties, allExtracted) = properties
          ->Array.map(((propName, propType, required)) => {
            let propBaseName = `${baseName}_${propName}`
            let (newType, extracted) = extractComplexTypes(
              ~baseName=propBaseName,
              ~irType=propType,
              ~threshold,
            )
            ((propName, newType, required), extracted)
          })
          ->Array.reduce(([], []), ((props, allExtr), ((prop, extracted))) => {
            (Array.concat(props, [prop]), Array.concat(allExtr, extracted))
          })
        
        let newType = Object({
          properties: newProperties,
          additionalProperties,
        })
        
        (Reference(`#/components/schemas/${baseName}`), Array.concat(allExtracted, [{
          name: baseName,
          description: None,
          type_: newType,
        }]))
      }
    | Array({items, constraints}) => {
        let (newItems, extracted) = extractComplexTypes(
          ~baseName=`${baseName}_Item`,
          ~irType=items,
          ~threshold,
        )
        (Array({items: newItems, constraints}), extracted)
      }
    | Union(types) => {
        let (newTypes, allExtracted) = types
          ->Array.mapWithIndex((type_, i) => {
            extractComplexTypes(
              ~baseName=`${baseName}_Variant${Int.toString(i)}`,
              ~irType=type_,
              ~threshold,
            )
          })
          ->Array.reduce(([], []), ((types, allExtr), ((type_, extracted))) => {
            (Array.concat(types, [type_]), Array.concat(allExtr, extracted))
          })
        (Union(newTypes), allExtracted)
      }
    | Option(inner) => {
        let (newInner, extracted) = extractComplexTypes(
          ~baseName,
          ~irType=inner,
          ~threshold,
        )
        (Option(newInner), extracted)
      }
    | other => (other, [])
    }
  }
}

// Check if two IR types are equal (shallow comparison for T | Array<T> detection)
let rec equals = (a: irType, b: irType): bool => {
  switch (a, b) {
  | (String(_), String(_)) => true
  | (Number(_), Number(_)) => true
  | (Integer(_), Integer(_)) => true
  | (Boolean, Boolean) => true
  | (Null, Null) => true
  | (Array({items: itemsA, _}), Array({items: itemsB, _})) => equals(itemsA, itemsB)
  | (Reference(refA), Reference(refB)) => refA == refB
  | (Option(innerA), Option(innerB)) => equals(innerA, innerB)
  | (Literal(litA), Literal(litB)) => {
      switch (litA, litB) {
      | (StringLiteral(a), StringLiteral(b)) => a == b
      | (NumberLiteral(a), NumberLiteral(b)) => a == b
      | (BooleanLiteral(a), BooleanLiteral(b)) => a == b
      | (NullLiteral, NullLiteral) => true
      | _ => false
      }
    }
  | (Unknown, Unknown) => true
  | _ => false
  }
}

// Pretty print IR type for debugging
let rec toString = (irType: irType): string => {
  switch irType {
  | String(_) => "String"
  | Number(_) => "Number"
  | Integer(_) => "Integer"
  | Boolean => "Boolean"
  | Null => "Null"
  | Array({items, _}) => `Array<${toString(items)}>`
  | Object({properties, _}) => {
      let props = properties
        ->Array.map(((name, type_, required)) => {
          let req = required ? "" : "?"
          `${name}${req}: ${toString(type_)}`
        })
        ->Array.join(", ")
      `{ ${props} }`
    }
  | Literal(StringLiteral(s)) => `"${s}"`
  | Literal(NumberLiteral(n)) => Float.toString(n)
  | Literal(BooleanLiteral(b)) => b ? "true" : "false"
  | Literal(NullLiteral) => "null"
  | Union(types) => {
      let typeStrs = types->Array.map(toString)->Array.join(" | ")
      `(${typeStrs})`
    }
  | Intersection(types) => {
      let typeStrs = types->Array.map(toString)->Array.join(" & ")
      `(${typeStrs})`
    }
  | Reference(ref) => ref
  | Option(inner) => `Option<${toString(inner)}>`
  | Unknown => "Unknown"
  }
}
