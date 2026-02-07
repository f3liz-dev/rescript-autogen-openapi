// SPDX-License-Identifier: MPL-2.0

// DiffReportGenerator.res - Generate Markdown reports for API diffs and merges
open Types

let formatEndpointName = (endpoint: endpoint) => {
  let methodPart = endpoint.method->String.toUpperCase
  let operationIdPart = endpoint.operationId->Option.mapOr("", id => ` (${id})`)
  `${methodPart} ${endpoint.path}${operationIdPart}`
}

let formatTags = tags =>
  tags->Option.mapOr("", tagList =>
    tagList->Array.length == 0 ? "" : ` [${tagList->Array.join(", ")}]`
  )

let generateMarkdownReport = (~diff: specDiff, ~baseName, ~forkName) => {
  let generateSection = (title, items, formatter) =>
    items->Array.length == 0 ? "" : `\n### ${title}\n\n${items->Array.map(formatter)->Array.join("\n")}\n`

  let totalChanges = SpecDiffer.countChanges(diff)
  let breakingChangesText = SpecDiffer.hasBreakingChanges(diff) ? "⚠️ Yes" : "✓ No"

  let summaryLines = [
    `- **Total Changes**: ${totalChanges->Int.toString}`,
    `- **Added Endpoints**: ${diff.addedEndpoints->Array.length->Int.toString}`,
    `- **Removed Endpoints**: ${diff.removedEndpoints->Array.length->Int.toString}`,
    `- **Modified Endpoints**: ${diff.modifiedEndpoints->Array.length->Int.toString}`,
    `- **Added Schemas**: ${diff.addedSchemas->Array.length->Int.toString}`,
    `- **Removed Schemas**: ${diff.removedSchemas->Array.length->Int.toString}`,
    `- **Modified Schemas**: ${diff.modifiedSchemas->Array.length->Int.toString}`,
    `- **Breaking Changes**: ${breakingChangesText}`,
  ]->Array.join("\n")

  let reportParts = [
    `# API Diff Report: ${baseName} → ${forkName}\n\n## Summary\n\n${summaryLines}`,
    generateSection("Added Endpoints", diff.addedEndpoints, (endpoint: endpoint) => {
      let endpointName = formatEndpointName(endpoint)
      let tags = formatTags(endpoint.tags)
      let summary = endpoint.summary->Option.mapOr("", summary => `\n  ${summary}`)
      `- **${endpointName}**${tags}${summary}`
    }),
    generateSection("Removed Endpoints", diff.removedEndpoints, (endpoint: endpoint) => {
      let endpointName = formatEndpointName(endpoint)
      let tags = formatTags(endpoint.tags)
      `- **${endpointName}**${tags}`
    }),
    generateSection("Modified Endpoints", diff.modifiedEndpoints, (endpointDiff: endpointDiff) => {
      let methodPart = endpointDiff.method->String.toUpperCase
      let breakingText = endpointDiff.breakingChange ? " **⚠️ BREAKING**" : ""
      let changes =
        [endpointDiff.requestBodyChanged ? "body" : "", endpointDiff.responseChanged ? "response" : ""]
        ->Array.filter(x => x != "")
        ->Array.join(", ")
      `- **${methodPart} ${endpointDiff.path}**${breakingText}: Changed ${changes}`
    }),
    generateSection("Added Schemas", diff.addedSchemas, schemaName => `- \`${schemaName}\``),
    generateSection("Removed Schemas", diff.removedSchemas, schemaName => `- \`${schemaName}\``),
    generateSection("Modified Schemas", diff.modifiedSchemas, (schemaDiff: schemaDiff) => {
      let breakingText = schemaDiff.breakingChange ? " **⚠️ BREAKING**" : ""
      `- \`${schemaDiff.name}\`${breakingText}`
    }),
    `\n---\n*Generated on ${Date.make()->Date.toISOString}*`,
  ]

  reportParts->Array.filter(part => part != "")->Array.join("\n")
}

let generateCompactSummary = (diff: specDiff) => {
  let totalChanges = SpecDiffer.countChanges(diff)
  let addedCount = diff.addedEndpoints->Array.length
  let removedCount = diff.removedEndpoints->Array.length
  let modifiedCount = diff.modifiedEndpoints->Array.length
  let breakingText = SpecDiffer.hasBreakingChanges(diff) ? " (BREAKING)" : ""

  `Found ${totalChanges->Int.toString} changes: +${addedCount->Int.toString} -${removedCount->Int.toString} ~${modifiedCount->Int.toString} endpoints${breakingText}`
}

let generateMergeReport = (~stats: SpecMerger.mergeStats, ~baseName, ~forkName) => {
  let sharedEndpoints = stats.sharedEndpointCount->Int.toString
  let sharedSchemas = stats.sharedSchemaCount->Int.toString
  let extensionEndpoints = stats.forkExtensionCount->Int.toString
  let extensionSchemas = stats.forkSchemaCount->Int.toString

  `
    |# Merge Report: ${baseName} + ${forkName}
    |
    |## Shared Code
    |
    |- **Shared Endpoints**: ${sharedEndpoints}
    |- **Shared Schemas**: ${sharedSchemas}
    |
    |## ${forkName} Extensions
    |
    |- **Extension Endpoints**: ${extensionEndpoints}
    |- **Extension Schemas**: ${extensionSchemas}
    |
    |## Summary
    |
    |The shared base contains ${sharedEndpoints} endpoints and ${sharedSchemas} schemas.
    |
    |${forkName} adds ${extensionEndpoints} endpoints and ${extensionSchemas} schemas.
    |
    |---
    |*Generated on ${Date.make()->Date.toISOString}*
    |`->CodegenUtils.trimMargin
}

let generateEndpointsByTagReport = (endpoints: array<endpoint>) => {
  let endpointsByTag = Dict.make()
  let untaggedEndpoints = []

  endpoints->Array.forEach(endpoint =>
    switch endpoint.tags {
    | None
    | Some([]) =>
      untaggedEndpoints->Array.push(endpoint)
    | Some(tags) =>
      tags->Array.forEach(tag => {
        let existing = Dict.get(endpointsByTag, tag)->Option.getOr([])
        existing->Array.push(endpoint)
        Dict.set(endpointsByTag, tag, existing)
      })
    }
  )

  let tagSections =
    Dict.keysToArray(endpointsByTag)
    ->Array.toSorted(String.compare)
    ->Array.map(tag => {
      let tagEndpoints = Dict.get(endpointsByTag, tag)->Option.getOr([])
      let count = tagEndpoints->Array.length->Int.toString
      let endpointList =
        tagEndpoints->Array.map(endpoint => `- ${formatEndpointName(endpoint)}`)->Array.join("\n")
      `### ${tag} (${count})\n\n${endpointList}`
    })
    ->Array.join("\n\n")

  let untaggedSection =
    untaggedEndpoints->Array.length > 0
      ? {
          let count = untaggedEndpoints->Array.length->Int.toString
          let endpointList =
            untaggedEndpoints
            ->Array.map(endpoint => `- ${formatEndpointName(endpoint)}`)
            ->Array.join("\n")
          `\n\n### Untagged (${count})\n\n${endpointList}`
        }
      : ""

  `## Endpoints by Tag\n\n${tagSections}${untaggedSection}`
}