# ⚡️ zig-bpe

This project implements a basic tokenizer in Zig, focusing on text processing and Byte Pair Encoding (BPE) concepts.

## What is Byte Pair Encoding

Byte Pair Encoding (BPE) is a data compression algorithm originally described by Philip Gage in 1994 [1]. It's also known as digram coding [2]. BPE works by iteratively replacing the most frequent pair of bytes in a sequence with a single, unused byte. This process continues until no byte pair occurs more than once.

In recent years, BPE has gained popularity in natural language processing, particularly for tokenization in large language models. The modified version used in NLP starts with a vocabulary of individual characters and iteratively merges the most frequent adjacent pairs to form new tokens. This allows the algorithm to effectively handle both single characters and entire words, making it particularly useful for processing text data [3].

BPE is notable for its simplicity and effectiveness in compressing data. It's especially useful in scenarios where the input data contains repeated sequences of bytes. The algorithm's ability to adapt to the specific patterns in the input data makes it a versatile choice for various compression tasks.

[1]: https://en.wikipedia.org/wiki/Byte_pair_encoding#cite_note-1
[2]: https://en.wikipedia.org/wiki/Byte_pair_encoding#cite_note-3
[3]: https://en.wikipedia.org/wiki/Byte_pair_encoding#cite_note-5

## Zig Version

This project is developed using Zig version 0.13.0. Make sure you have this version installed to build and run the project successfully.

## Features

- Read input from a file
- Convert text to initial tokens
- Expand vocabulary using a simplified BPE-like approach
- Train the tokenizer on input text
- Measure and report performance statistics
- Encode and decode text using the trained tokenizer
- Serialize and deserialize merge operations

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
8. **Encoding and Decoding**: Provides methods to encode text into tokens and decode tokens back into text.
9. **Clear API**: Offers a clear and easy-to-use API for tokenization, training, and serialization.

## Serialization and Deserialization

The tokenizer supports serializing and deserializing merge operations, allowing you to save and load the trained model.

## Testing

The project includes several unit tests to ensure the correct functionality of the tokenizer. These tests cover various aspects of the `BasicTokenizer` implementation:

1. **generateInitialTokens**: Tests the initial tokenization of a string into individual characters.
2. **encode**: Verifies the encoding process, including the application of learned merges.
3. **decode**: Checks the decoding process, ensuring encoded tokens are correctly converted back to text.
4. **train**: Tests the training process, including merge operations and vocabulary expansion.
5. **serializeMerges and deserializeMerges**: Ensures that merge operations can be correctly saved to and loaded from a file.

### Running the Tests

To run all the tests for the project, use the following command in the root directory of the project:

```
zig test src/basic_tokenizer.zig
```

This command will compile and run all the tests defined in the `basic_tokenizer.zig` file.

To run tests for other specific files, replace

```
zig test src/basic_tokenizer.zig
```

This command will compile and run all the tests defined in the `basic_tokenizer.zig` file.

### Test Output

When you run the tests, Zig will compile the code and execute each test function. The output will show which tests passed or failed, along with any debug information printed during the tests.

If all tests pass, you'll see a message indicating success. If any tests fail, Zig will provide detailed information about the failure, including the line number and the nature of the assertion that failed.
