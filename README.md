# BPE Compression in Zig

This project implements Byte Pair Encoding (BPE) compression in Zig. It includes functionality to compress tokens using BPE, expand the vocabulary, and decode compressed tokens.

## Features

- Read input from a file
- Convert text to tokens
- Compute statistics on token pairs
- Replace top pairs with new indices
- Expand vocabulary using BPE algorithm
- Create vocabulary from merges
- Decode compressed tokens back to original text

## File Structure

- `src/main.zig`: Main implementation of BPE compression, expansion, and decoding
- `src/constants.zig`: Constants used throughout the project
- `src/compression.test.zig`: Comprehensive test cases for all major functions

## Running the Project

To run the main program:

```
zig run src/main.zig
```

## Testing

To run the tests for this project:

```
zig test src/compression.test.zig
```

This will execute the test cases defined in `compression.test.zig`, which verify the functionality of the compression, expansion, and decoding algorithms.

## Configuration

You can modify the `INPUT_FILE_PATH` and `DEFAULT_INDEX` in `constants.zig` to change the input file and the replacement index used in compression.

## Simplified UTF-8 Handling

The current implementation and tests are designed to work with simplified UTF-8. This means that the code assumes the input text is valid UTF-8 and does not handle all edge cases of UTF-8 encoding. Specifically:

- The `getTokensFromString` function converts UTF-8 encoded text into Unicode code points, assuming all characters fit within the `u21` type.
- The `getStringFromTokens` function converts Unicode code points back into UTF-8 encoded text.
- The tests in `src/compression.test.zig` verify the functionality using simplified UTF-8 input files.

## Recent Changes

- Added unit tests to verify the compression, expansion, and decoding algorithms' functionality.
- Made key functions public to allow testing from external modules.
- Updated the implementation to handle simplified UTF-8 encoding and decoding.

## License

[Add your chosen license here]

## Limitations

The current implementation and tests only work with simplified UTF-8 encoding, which means it may not correctly handle all Unicode characters or edge cases. Future updates will focus on improving Unicode support.
