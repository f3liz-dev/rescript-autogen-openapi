// Example: Using the new ReScript thin wrapper
// This demonstrates the pipe-first ergonomic API

// Note: Replace 'MisskeyWrapper' with the actual wrapper name generated from your API spec
// The wrapper is named [APITitle]Wrapper.res based on your OpenAPI spec's info.title field
// For example: MisskeyWrapper, PetstoreWrapper, etc.

// Connect to Misskey instance
let client = MisskeyWrapper.connect("https://misskey.io", ~token="your-token-here", ())

// Example 1: Create a note (pipe-first style!)
let createNote = async () => {
  {text: "Hello from ReScript! 🚀"}
    ->MisskeyWrapper.Notes.postNotesCreate(~client)
    ->Promise.then(note => {
      Console.log2("✅ Created note:", note.id)
      Promise.resolve(note)
    })
    ->Promise.catch(error => {
      Console.error2("❌ Failed to create note:", error)
      Promise.reject(error)
    })
}

// Example 2: Get timeline
let getTimeline = async () => {
  {
    limit: Some(20),
    local: Some(true),
    sinceId: None,
    untilId: None,
  }
    ->MisskeyWrapper.Notes.postNotes(~client)
    ->Promise.then(notes => {
      Console.log2("📝 Got notes:", Array.length(notes))
      Promise.resolve(notes)
    })
}

// Example 3: React to a note
let reactToNote = async (noteId: string) => {
  {noteId, reaction: "👍"}
    ->MisskeyWrapper.Notes.postNotesReactionsCreate(~client)
    ->Promise.then(() => {
      Console.log("👍 Reacted successfully!")
      Promise.resolve()
    })
}

// Example 4: Chain operations
let postAndReact = async () => {
  // Create note
  let note = await {text: "Chain example"}->MisskeyWrapper.Notes.postNotesCreate(~client)
  
  // React to it
  await {noteId: note.id, reaction: "❤️"}->MisskeyWrapper.Notes.postNotesReactionsCreate(~client)
  
  Console.log("✨ Posted and reacted!")
}

// Example 5: Named parameter style (alternative)
let createNoteAlt = async () => {
  MisskeyWrapper.Notes.postNotesCreate(
    {text: "Using named params"},
    ~client
  )
}

// Usage
let main = async () => {
  Console.log("🚀 Starting Misskey demo...\n")
  
  let note = await createNote()
  let _ = await getTimeline()
  let _ = await reactToNote(note.id)
  let _ = await postAndReact()
  
  Console.log("\n✅ All done!")
}

// Run it
main()->Promise.catch(error => {
  Console.error2("💥 Error:", error)
  Promise.resolve()
})
