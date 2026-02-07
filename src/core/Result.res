// SPDX-License-Identifier: MPL-2.0

// Result.res - Railway-oriented programming helpers
// Compact utilities for elegant error handling with pipe-first style

// Re-export core Result for convenience
include Result

// Applicative-style combinators  
let map2 = (ra, rb, f) =>
  switch (ra, rb) {
  | (Ok(a), Ok(b)) => Ok(f(a, b))
  | (Error(e), _) => Error(e)
  | (_, Error(e)) => Error(e)
  }

let map3 = (ra, rb, rc, f) =>
  switch (ra, rb, rc) {
  | (Ok(a), Ok(b), Ok(c)) => Ok(f(a, b, c))
  | (Error(e), _, _) => Error(e)
  | (_, Error(e), _) => Error(e)
  | (_, _, Error(e)) => Error(e)
  }

let map4 = (ra, rb, rc, rd, f) =>
  switch (ra, rb, rc, rd) {
  | (Ok(a), Ok(b), Ok(c), Ok(d)) => Ok(f(a, b, c, d))
  | (Error(e), _, _, _) => Error(e)
  | (_, Error(e), _, _) => Error(e)
  | (_, _, Error(e), _) => Error(e)
  | (_, _, _, Error(e)) => Error(e)
  }

// Collect array of results into result of array
let all = results => {
  let acc = []
  let error = ref(None)
  let len = Array.length(results)
  
  let rec loop = idx => {
    if idx < len && Option.isNone(error.contents) {
      switch Array.getUnsafe(results, idx) {
      | Ok(v) => {
          Array.push(acc, v)
          loop(idx + 1)
        }
      | Error(e) => error := Some(e)
      }
    }
  }
  
  loop(0)
  
  switch error.contents {
  | Some(e) => Error(e)
  | None => Ok(acc)
  }
}

// Collect results, ignoring successful values (just check for errors)
let allUnit = results => {
  let error = ref(None)
  let len = Array.length(results)
  
  let rec loop = idx => {
    if idx < len && Option.isNone(error.contents) {
      switch Array.getUnsafe(results, idx) {
      | Ok(_) => loop(idx + 1)
      | Error(e) => error := Some(e)
      }
    }
  }
  
  loop(0)
  
  switch error.contents {
  | Some(e) => Error(e)
  | None => Ok()
  }
}

// Partition results into successes and errors
let partition = results => {
  let successes = []
  let errors = []
  results->Array.forEach(r =>
    switch r {
    | Ok(v) => successes->Array.push(v)
    | Error(e) => errors->Array.push(e)
    }
  )
  (successes, errors)
}

// Try multiple computations, return first success or all errors
let firstSuccess = results => {
  let errors = []
  let success = ref(None)
  let len = Array.length(results)
  
  let rec loop = idx => {
    if idx < len && Option.isNone(success.contents) {
      switch Array.getUnsafe(results, idx) {
      | Ok(v) => success := Some(v)
      | Error(e) => {
          Array.push(errors, e)
          loop(idx + 1)
        }
      }
    }
  }
  
  loop(0)
  
  switch success.contents {
  | Some(v) => Ok(v)
  | None => Error(errors)
  }
}

// Fold with early exit on error
let foldM = (arr, init, f) => {
  let rec loop = (acc, idx) =>
    if idx >= Array.length(arr) {
      Ok(acc)
    } else {
      f(acc, arr->Array.getUnsafe(idx))->flatMap(newAcc => loop(newAcc, idx + 1))
    }
  loop(init, 0)
}

// Tap for side effects (useful for logging)
let tap = (result, f) => {
  switch result {
  | Ok(v) => f(v)
  | Error(_) => ()
  }
  result
}

let tapError = (result, f) => {
  switch result {
  | Error(e) => f(e)
  | Ok(_) => ()
  }
  result
}

// Convert option to result
let fromOption = (opt, error) =>
  switch opt {
  | Some(v) => Ok(v)
  | None => Error(error)
  }

// Convert to option (discarding error)
let toOption = result =>
  switch result {
  | Ok(v) => Some(v)
  | Error(_) => None
  }

// Recover from error with a function
let recover = (result, f) =>
  switch result {
  | Ok(_) as ok => ok
  | Error(e) => f(e)
  }

// Pipe-first versions of common operations
let getOr = (result, default) =>
  switch result {
  | Ok(v) => v
  | Error(_) => default
  }

let getExn = result =>
  switch result {
  | Ok(v) => v
  | Error(_) => panic("Result.getExn called on Error")
  }

let getError = result =>
  switch result {
  | Ok(_) => None
  | Error(e) => Some(e)
  }
