// SPDX-License-Identifier: MPL-2.0

// Codegen.res - Main code generation orchestrator (DOP refactored)
open Types

// Promise bindings
@val external promiseAll: array<promise<'a>> => promise<array<'a>> = "Promise.all"

// Generate code from a single spec (pure - returns data)
@genType
let generateSingleSpecPure = (~spec: openAPISpec, ~config: generationConfig): result<Pipeline.t, codegenError> => {
  try {
    let targets = config.targets->Option.getOr(Config.defaultTargets())
    let allEndpoints = OpenAPIParser.getAllEndpoints(spec)
    let endpoints = switch config.includeTags {
    | None => allEndpoints
    | Some(includeTags) => OpenAPIParser.filterByTags(~endpoints=allEndpoints, ~includeTags, ~excludeTags=config.excludeTags->Option.getOr([]))
    }
    
    let baseOutput = targets.rescriptApi 
      ? Pipeline.combine([
          ComponentSchemaGenerator.generate(~spec, ~outputDir=config.outputDir),
          config.modulePerTag
            ? ModuleGenerator.generateTagModuleFiles(
                ~endpoints,
                ~outputDir=config.outputDir,
                ~overrideDir=?config.docOverrideDir,
              )
            : ModuleGenerator.generateFlatModuleFile(
                ~moduleName="API",
                ~endpoints,
                ~outputDir=config.outputDir,
                ~overrideDir=?config.docOverrideDir,
              ),
        ])
      : Pipeline.empty

    let wrapperOutput = targets.rescriptWrapper
      ? ThinWrapperGenerator.generateWrapper(~spec, ~endpoints, ~outputDir=config.outputDir, ~wrapperModuleName=CodegenUtils.toPascalCase(spec.info.title) ++ "Wrapper", ~generatedModulePrefix="")
      : Pipeline.empty

    let dtsOutput = targets.typescriptDts
      ? TypeScriptDtsGenerator.generate(~spec, ~endpoints, ~outputDir=config.dtsOutputDir->Option.getOr(config.outputDir))
      : Pipeline.empty

    let tsWrapperOutput = targets.typescriptWrapper
      ? TypeScriptWrapperGenerator.generate(~endpoints, ~outputDir=config.wrapperOutputDir->Option.getOr(config.outputDir), ~generatedModulePath="../generated")
      : Pipeline.empty

    Result.Ok(Pipeline.combine([baseOutput, wrapperOutput, dtsOutput, tsWrapperOutput]))
  } catch {
  | JsExn(err) => Result.Error(UnknownError({message: err->JsExn.message->Option.getOr("Unknown error"), context: None}))
  | _ => Result.Error(UnknownError({message: "Unknown error", context: None}))
  }
}

// Generate code from a single spec (with side effects)
@genType
let generateSingleSpec = async (~spec: openAPISpec, ~config: generationConfig): generationResult => {
  switch generateSingleSpecPure(~spec, ~config) {
  | Result.Error(err) => Result.Error(err)
  | Result.Ok(output) =>
    switch FileSystem.writeFiles(output.files) {
    | Result.Error(errors) => Result.Error(UnknownError({message: `Failed to write files: ${Array.join(errors, ", ")}`, context: None}))
    | Result.Ok(filePaths) =>
      let overrideFiles = switch config.generateDocOverrides {
      | Some(true) =>
          let allEndpoints = OpenAPIParser.getAllEndpoints(spec)
          let endpoints = switch config.includeTags {
          | None => allEndpoints
          | Some(includeTags) => OpenAPIParser.filterByTags(~endpoints=allEndpoints, ~includeTags, ~excludeTags=config.excludeTags->Option.getOr([]))
          }
          let files = DocOverride.generateOverrideFiles(~spec, ~endpoints, ~outputDir=config.docOverrideDir->Option.getOr("./docs"), ~host=spec.info.title, ~groupByTag=config.modulePerTag, ())
          FileSystem.writeFiles(files)->Result.getOr([])
      | _ => []
      }
      Result.Ok({generatedFiles: Array.concat(filePaths, overrideFiles), diff: None, warnings: output.warnings})
    }
  }
}

// Process a single fork (pure - returns data)
let processForkPure = (~baseSpec: openAPISpec, ~baseEndpoints: array<endpoint>, ~fork: forkSpec, ~config: generationConfig): result<Pipeline.t, codegenError> => {
  try {
    let forkEndpoints = OpenAPIParser.getAllEndpoints(fork.spec)
    let diff = SpecDiffer.generateDiff(~baseSpec, ~forkSpec=fork.spec, ~baseEndpoints, ~forkEndpoints)
    
    let diffReportFile: option<FileSystem.fileToWrite> = config.generateDiffReport 
      ? Some({path: FileSystem.makePath(config.outputDir, `${fork.name}-diff.md`), content: DiffReportGenerator.generateMarkdownReport(~diff, ~baseName="base", ~forkName=fork.name)})
      : None

    let (sharedSpec, extensionsSpec) = SpecMerger.mergeSpecs(~baseSpec, ~forkSpec=fork.spec, ~baseEndpoints, ~forkEndpoints, ~strategy=config.strategy)
    let sharedEndpoints = OpenAPIParser.getAllEndpoints(sharedSpec)
    let extensionEndpoints = OpenAPIParser.getAllEndpoints(extensionsSpec)
    
    let mergeReportFile: FileSystem.fileToWrite = {
      path: FileSystem.makePath(config.outputDir, `${fork.name}-merge.md`),
      content: DiffReportGenerator.generateMergeReport(~stats=SpecMerger.getMergeStats(~baseEndpoints, ~forkEndpoints, ~baseSchemas=baseSpec.components->Option.flatMap(c => c.schemas), ~forkSchemas=fork.spec.components->Option.flatMap(c => c.schemas)), ~baseName="base", ~forkName=fork.name)
    }

    let codeOutput = switch config.strategy {
    | Separate =>
      Pipeline.fromFile({
        path: FileSystem.makePath(config.outputDir, `${fork.name}.res`),
        content: ModuleGenerator.generateFlatModuleCode(
          ~moduleName=CodegenUtils.toPascalCase(fork.name),
          ~endpoints=forkEndpoints,
          ~overrideDir=?config.docOverrideDir,
        ),
      })
    | SharedBase =>
        let baseName = config.baseInstanceName->Option.getOrThrow(~message="baseInstanceName required")
        let basePrefix = config.baseModulePrefix->Option.getOr(CodegenUtils.toPascalCase(baseName))
        ModuleGenerator.generateSeparatePerTagModules(~baseName, ~basePrefix, ~forkName=fork.name, ~sharedEndpoints, ~extensionEndpoints, ~sharedSchemas=sharedSpec.components->Option.flatMap(c => c.schemas), ~extensionSchemas=fork.spec.components->Option.flatMap(c => c.schemas), ~outputDir=config.outputDir, ~overrideDir=?config.docOverrideDir)
    }

    let targets = config.targets->Option.getOr({rescriptApi: true, rescriptWrapper: false, typescriptDts: false, typescriptWrapper: false})
    let (wSpec, wShared, wExt, wBasePrefix) = switch config.strategy {
    | Separate => (fork.spec, forkEndpoints, [], "")
    | SharedBase => (sharedSpec, sharedEndpoints, extensionEndpoints, config.baseModulePrefix->Option.getOr(config.baseInstanceName->Option.map(CodegenUtils.toPascalCase)->Option.getOr("")))
    }

    let wrapperOutput = targets.rescriptWrapper 
      ? ThinWrapperGenerator.generateWrapper(~spec=wSpec, ~endpoints=wShared, ~extensionEndpoints=wExt, ~outputDir=FileSystem.makePath(config.outputDir, fork.name), ~wrapperModuleName=CodegenUtils.toPascalCase(fork.name) ++ "Wrapper", ~generatedModulePrefix=CodegenUtils.toPascalCase(fork.name), ~baseModulePrefix=wBasePrefix)
      : Pipeline.empty

    let allWEndpoints = Array.concat(wShared, wExt)
    let dtsOutput = targets.typescriptDts 
      ? TypeScriptDtsGenerator.generate(~spec=wSpec, ~endpoints=allWEndpoints, ~outputDir=FileSystem.makePath(config.dtsOutputDir->Option.getOr(config.outputDir), fork.name))
      : Pipeline.empty

    let tsWrapperOutput = targets.typescriptWrapper 
      ? TypeScriptWrapperGenerator.generate(~endpoints=allWEndpoints, ~outputDir=FileSystem.makePath(config.wrapperOutputDir->Option.getOr(config.outputDir), fork.name), ~generatedModulePath=`../../generated/${fork.name}`)
      : Pipeline.empty

    let reports = Pipeline.fromFiles([mergeReportFile, ...diffReportFile->Option.map(f => [f])->Option.getOr([])])
    Result.Ok(Pipeline.combine([reports, codeOutput, wrapperOutput, dtsOutput, tsWrapperOutput]))
  } catch {
  | JsExn(err) => Result.Error(UnknownError({message: err->JsExn.message->Option.getOr("Unknown error"), context: None}))
  | _ => Result.Error(UnknownError({message: "Unknown error", context: None}))
  }
}

// Generate code from multiple specs (pure - returns data)
@genType
let generateMultiSpecPure = (~baseSpec: openAPISpec, ~forkSpecs: array<forkSpec>, ~config: generationConfig): result<Pipeline.t, codegenError> => {
  try {
    let baseEndpoints = OpenAPIParser.getAllEndpoints(baseSpec)
    let forkResults = forkSpecs->Array.map(fork => processForkPure(~baseSpec, ~baseEndpoints, ~fork, ~config))
    
    switch forkResults->Array.find(Result.isError) {
    | Some(Result.Error(err)) => Result.Error(err)
    | _ =>
        let outputs = forkResults->Array.filterMap(res => switch res { | Ok(v) => Some(v) | Error(_) => None })
        let targets = config.targets->Option.getOr(Config.defaultTargets())
        let baseName = config.baseInstanceName->Option.getOrThrow(~message="baseInstanceName required")
        let basePrefix = config.baseModulePrefix->Option.getOr(CodegenUtils.toPascalCase(baseName))
        let baseOutputDir = FileSystem.makePath(config.outputDir, baseName)
        
        let baseWrappers = Pipeline.combine([
          targets.rescriptWrapper ? ThinWrapperGenerator.generateWrapper(~spec=baseSpec, ~endpoints=baseEndpoints, ~outputDir=baseOutputDir, ~wrapperModuleName=basePrefix ++ "Wrapper", ~generatedModulePrefix=basePrefix) : Pipeline.empty,
          targets.typescriptDts ? TypeScriptDtsGenerator.generate(~spec=baseSpec, ~endpoints=baseEndpoints, ~outputDir=FileSystem.makePath(config.dtsOutputDir->Option.getOr(config.outputDir), baseName)) : Pipeline.empty,
          targets.typescriptWrapper ? TypeScriptWrapperGenerator.generate(~endpoints=baseEndpoints, ~outputDir=FileSystem.makePath(config.wrapperOutputDir->Option.getOr(config.outputDir), baseName), ~generatedModulePath=`../../generated/${baseName}`) : Pipeline.empty
        ])
        
        Result.Ok(Pipeline.combine(Array.concat(outputs, [baseWrappers])))
    }
  } catch {
  | JsExn(err) => Result.Error(UnknownError({message: err->JsExn.message->Option.getOr("Unknown error"), context: None}))
  | _ => Result.Error(UnknownError({message: "Unknown error", context: None}))
  }
}

// Generate code from multiple specs (with side effects)
@genType
let generateMultiSpec = async (~baseSpec: openAPISpec, ~forkSpecs: array<forkSpec>, ~config: generationConfig): generationResult =>
  switch generateMultiSpecPure(~baseSpec, ~forkSpecs, ~config) {
  | Result.Error(err) => Result.Error(err)
  | Result.Ok(output) =>
      FileSystem.writeFiles(output.files)
      ->Result.map(filePaths => ({generatedFiles: filePaths, diff: None, warnings: output.warnings}: generationSuccess))
      ->Result.mapError(errors => UnknownError({message: `Failed to write files: ${Array.join(errors, ", ")}`, context: None}))
  }

// Compare two specs and generate diff report
@genType
let compareSpecs = async (~baseSpec, ~forkSpec, ~baseName="base", ~forkName="fork", ~outputPath=?) => {
  let diff = SpecDiffer.generateDiff(~baseSpec, ~forkSpec, ~baseEndpoints=OpenAPIParser.getAllEndpoints(baseSpec), ~forkEndpoints=OpenAPIParser.getAllEndpoints(forkSpec))
  outputPath->Option.forEach(path => {
    let _ = FileSystem.writeFile({path, content: DiffReportGenerator.generateMarkdownReport(~diff, ~baseName, ~forkName)})
  })
  diff
}

// Main generation function
@genType
let generate = async (config: generationConfig): generationResult => {
  switch await SchemaRefResolver.resolve(config.specPath) {
  | Result.Error(message) => Result.Error(SpecResolutionError({url: config.specPath, message}))
  | Result.Ok(baseSpec) =>
      switch config.forkSpecs {
      | None | Some([]) => await generateSingleSpec(~spec=baseSpec, ~config)
      | Some(forkConfigs) =>
          let forkResults = await forkConfigs
            ->Array.map(async f => (await SchemaRefResolver.resolve(f.specPath))->Result.map(spec => ({name: f.name, spec}: forkSpec)))
            ->promiseAll
          
          switch forkResults->Array.find(Result.isError) {
          | Some(Result.Error(err)) => Result.Error(SpecResolutionError({url: "", message: err}))
          | _ => await generateMultiSpec(~baseSpec, ~forkSpecs=forkResults->Array.filterMap(res => switch res { | Ok(v) => Some(v) | Error(_) => None }), ~config)
          }
      }
  }
}

@genType
let createDefaultConfig = (url, outputDir): generationConfig => ({
  specPath: url, outputDir, strategy: SharedBase, includeTags: None, excludeTags: None,
  modulePerTag: true, generateDiffReport: true, breakingChangeHandling: Warn,
  forkSpecs: None, generateDocOverrides: None, docOverrideDir: None,
  targets: None, dtsOutputDir: None, wrapperOutputDir: None,
  baseInstanceName: None, baseModulePrefix: None,
})

@genType
let generateFromUrl = async (~url, ~outputDir, ~config=?) => 
  await generate({...config->Option.getOr(createDefaultConfig(url, outputDir)), specPath: url})

@genType
let generateFromFile = async (~filePath, ~outputDir, ~config=?) => 
  await generate({...config->Option.getOr(createDefaultConfig(filePath, outputDir)), specPath: filePath})
