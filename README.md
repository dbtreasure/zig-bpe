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
zig test src/main.zig
```

This will execute the test cases defined in `main.zig`, which verify the functionality of the BasicTokenizer, including training and vocabulary size error handling.

## License

[Add your chosen license here]

## Limitations

The current implementation works with UTF-8 encoded text but may not handle all edge cases of UTF-8 encoding. Future updates may focus on improving Unicode support and handling more complex scenarios.

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
