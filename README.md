# Zig Text Compression Tool

## Purpose

This Zig program implements a simple text compression algorithm. It reads an input file, identifies the most frequent character pair, and replaces all occurrences of that pair with a single index. This process can be used as a basic step in text compression techniques.

## Build Instructions

1. Ensure you have Zig installed on your system. If not, download it from [ziglang.org](https://ziglang.org/).

2. Clone this repository:

   ```
   git clone [your-repository-url]
   cd [your-repository-name]
   ```

3. Build the project:
   ```
   zig build
   ```

## Running the Program

1. Make sure you have an input file ready. The default path is set in `constants.zig`.

2. Run the compiled program:

   ```
   ./zig-out/bin/[your-program-name]
   ```

3. The program will output:
   - The most frequent character pair
   - The length of the original token list
   - The length of the new token list after compression

## Configuration

You can modify the `INPUT_FILE_PATH` and `DEFAULT_INDEX` in `constants.zig` to change the input file and the replacement index used in compression.

## License

[Add your chosen license here]
