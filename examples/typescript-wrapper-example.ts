// Example: Using the new TypeScript wrapper
// This demonstrates the client-first ergonomic API for TypeScript

import { MisskeyClient, Notes } from './wrapper';

// Create a client instance
const client = new MisskeyClient('https://misskey.io', 'your-token-here');

// Example 1: Create a note
async function createNote() {
  const note = await Notes.postNotesCreate(client, {
    text: "Hello from TypeScript! 🚀"
  });
  
  console.log('✅ Created note:', note.id);
  return note;
}

// Example 2: Get timeline
async function getTimeline() {
  const notes = await Notes.postNotes(client, {
    limit: 20,
    local: true,
  });
  
  console.log('📝 Got notes:', notes.length);
  return notes;
}

// Example 3: React to a note
async function reactToNote(noteId: string) {
  await Notes.postNotesReactionsCreate(client, {
    noteId,
    reaction: '👍'
  });
  
  console.log('👍 Reacted successfully!');
}

// Example 4: Chain operations
async function postAndReact() {
  // Create note
  const note = await Notes.postNotesCreate(client, {
    text: "Chain example"
  });
  
  // React to it
  await Notes.postNotesReactionsCreate(client, {
    noteId: note.id,
    reaction: '❤️'
  });
  
  console.log('✨ Posted and reacted!');
}

// Example 5: With full TypeScript types
import type { 
  PostNotesCreateRequest,
  PostNotesCreateResponse 
} from './types/Notes';

async function createNoteTyped(
  request: PostNotesCreateRequest
): Promise<PostNotesCreateResponse> {
  return Notes.postNotesCreate(client, request);
}

// Example 6: Error handling
async function createNoteWithErrorHandling() {
  try {
    const note = await Notes.postNotesCreate(client, {
      text: "Error handling example"
    });
    
    console.log('✅ Success:', note.id);
    return note;
  } catch (error) {
    console.error('❌ Failed:', error);
    throw error;
  }
}

// Example 7: Multiple clients
const publicClient = new MisskeyClient('https://misskey.io');
const privateClient = new MisskeyClient('https://misskey.io', 'secret-token');

async function useMultipleClients() {
  // Public timeline (no auth)
  const publicNotes = await Notes.postNotes(publicClient, {
    limit: 10,
    local: true
  });
  
  // Create note (requires auth)
  const myNote = await Notes.postNotesCreate(privateClient, {
    text: "Posted with authentication"
  });
  
  console.log('Public notes:', publicNotes.length);
  console.log('My note:', myNote.id);
}

// Main function
async function main() {
  console.log('🚀 Starting Misskey TypeScript demo...\n');
  
  const note = await createNote();
  await getTimeline();
  await reactToNote(note.id);
  await postAndReact();
  await createNoteTyped({ text: "Typed example" });
  await useMultipleClients();
  
  console.log('\n✅ All done!');
}

// Run it
main().catch(error => {
  console.error('💥 Error:', error);
  process.exit(1);
});
