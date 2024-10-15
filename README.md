# GMD Rummy Score

GMD Rummy Score is a SwiftUI-based iOS application designed to help players keep track of scores in the card game Rummy. This app provides an easy-to-use interface for managing multiple players, rounds, and various scoring options.

## Features

- Start a new game with customizable scoring rules
- Add multiple players to a game
- Keep track of scores for each player across multiple rounds
- Support for different scoring options:
  - Zero
  - Game
  - Drop
  - Middle Drop
  - Full Count
  - Custom score entry
- Export game results to CSV file
- Persistent game state (app remembers scores even if closed abruptly)
- Clean and intuitive user interface

## How to Use

1. **Start a New Game**: 
   - Set the game rules (Drop, Middle Drop, and Full Count values)
   - Tap "Start New Game"

2. **Add Players**:
   - Enter a player's name and tap "Add Player"
   - Repeat for all players in the game

3. **Score Keeping**:
   - For each round, select a score option or enter a custom score for each player
   - Tap the "+" button to add a new round

4. **Export Game**:
   - Tap the export button in the top-right corner to save the game results as a CSV file

5. **End Game**:
   - Tap the power button in the top-right corner to end the current game

## Technical Details

- Built with SwiftUI
- Targets iOS 14.0 and above
- Uses `UserDefaults` for persisting game state
- Implements custom UI components like `CustomTextField` for better user experience

## Installation

1. Clone this repository
2. Open the project in Xcode 12 or later
3. Build and run the project on your iOS device or simulator

## Contributing

Contributions, issues, and feature requests are welcome. Feel free to check issues page if you want to contribute.

## License

[MIT License](https://opensource.org/licenses/MIT)

## Author

[Your Name]
