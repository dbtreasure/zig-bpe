# BPE Compression in Zig

This project implements Byte Pair Encoding (BPE) compression in Zig. It includes functionality to compress tokens using BPE and expand the vocabulary.

## Features

- Read input from a file
- Convert text to tokens
- Compute statistics on token pairs
- Replace top pairs with new indices
- Expand vocabulary using BPE algorithm

## File Structure

- `src/main.zig`: Main implementation of BPE compression and expansion
- `src/constants.zig`: Constants used throughout the project
- `src/compression.test.zig`: Test cases for compression and expansion functions

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

This will execute the test cases defined in `compression.test.zig`, which verify the functionality of the compression and expansion algorithms.

## Configuration

You can modify the `INPUT_FILE_PATH` and `DEFAULT_INDEX` in `constants.zig` to change the input file and the replacement index used in compression.

## Recent Changes

- Added unit tests to verify the compression and expansion algorithms' functionality.
- Made key functions public to allow testing from external modules.

## License

[Add your chosen license here]
