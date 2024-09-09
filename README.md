# Zig Tokenizer

This project implements a basic tokenizer in Zig, focusing on text processing and Byte Pair Encoding (BPE) concepts.

## Features

- Read input from a file
- Convert text to initial tokens
- Expand vocabulary using a simplified BPE-like approach
- Train the tokenizer on input text
- Measure and report performance statistics

## File Structure

- `src/main.zig`: Main entry point and example usage
- `src/basic_tokenizer.zig`: Core implementation of the BasicTokenizer
- `src/utils/read_file.zig`: Utility function for reading files
- `src/utils/time_statistics.zig`: Performance measurement utilities

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

This will execute the test cases defined in `compression.test.zig`, which verify the functionality of the compression, expansion, encoding, and decoding algorithms.

## Configuration

You can modify the `INPUT_FILE_PATH` and `DEFAULT_INDEX` in `constants.zig` to change the input file and the replacement index used in compression.

## Simplified UTF-8 Handling

The current implementation and tests are designed to work with simplified UTF-8. This means that the code assumes the input text is valid UTF-8 and does not handle all edge cases of UTF-8 encoding. Specifically:

- The `getTokensFromString` function converts UTF-8 encoded text into Unicode code points, assuming all characters fit within the `u21` type.
- The `getStringFromTokens` function converts Unicode code points back into UTF-8 encoded text.
- The tests in `src/compression.test.zig` verify the functionality using simplified UTF-8 input files.

## Recent Changes

- Added unit tests to verify the compression, expansion, encoding, and decoding algorithms' functionality.
- Made key functions public to allow testing from external modules.
- Updated the implementation to handle simplified UTF-8 encoding and decoding.
- Extracted the logic for finding the longest matching sequence into a separate function.
- Added a new test case to test the encoding and decoding process using the `simple_input.txt` file.

## License

[Add your chosen license here]

## Limitations

The current implementation and tests only work with simplified UTF-8 encoding, which means it may not correctly handle all Unicode characters or edge cases. Future updates will focus on improving Unicode support.

## Current Implementation (basic_tokenizer.zig)

The `basic_tokenizer.zig` file provides the core implementation of the tokenizer. Key features include:

1. **Modular Structure**: The code is organized into a `BasicTokenizer` struct, encapsulating all tokenization-related functionality.

2. **Memory Management**: Uses Zig's allocator interface for efficient memory management.

3. **UTF-8 Handling**: The implementation handles UTF-8 encoded text, supporting a wide range of input data.

4. **Vocabulary Management**: Includes methods for creating and managing the tokenizer's vocabulary.

5. **Flexible Token Type**: Uses appropriate types for tokens, allowing for customizable vocabulary sizes.

6. **Error Handling**: Implements error handling throughout the tokenization process.

7. **Training Functionality**: Includes a `train` method to learn from input text.

8. **Clear API**: Offers a clear and easy-to-use API for tokenization and training.

This implementation provides a foundation for text tokenization, suitable for various applications and input data types.
