// SPDX-License-Identifier: MPL-2.0

// Toposort.res - ReScript bindings for the toposort npm package

type toposortModule

@module("toposort") external toposortModule: toposortModule = "default"

// toposort.array(nodes, edges) — sort nodes topologically given directed edges
// edges: array of [from, to] meaning "from depends on to" (to must come before from)
// Returns sorted array (dependencies first)
// Throws on cycles
@send
external array: (toposortModule, array<string>, array<(string, string)>) => array<string> = "array"

let sortArray = (nodes, edges) => toposortModule->array(nodes, edges)
