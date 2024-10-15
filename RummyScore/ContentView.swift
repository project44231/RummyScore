import SwiftUI
import UniformTypeIdentifiers

// Enum to represent score options with their corresponding values
enum ScoreOption: String, CaseIterable, Codable {
    case zero = "0"
    case game = "Game"
    case drop = "Drop"
    case middleDrop = "M-Drop"
    case fullCount = "Full Count"
    case custom = "Custom"

    var value: Int {
        switch self {
        case .zero:
            return 0
        case .game:
            return 0
        case .drop:
            return ScoreSettings.shared.dropValue
        case .middleDrop:
            return ScoreSettings.shared.middleDropValue
        case .fullCount:
            return ScoreSettings.shared.fullCountValue
        case .custom:
            return -1  // Custom value needs to be set by the user
        }
    }
}

// Singleton for managing score settings
class ScoreSettings: ObservableObject {
    static let shared = ScoreSettings()
    @Published var dropValue: Int = 25
    @Published var middleDropValue: Int = 40
    @Published var fullCountValue: Int = 80
}

// Struct to handle player scores
struct PlayerScore: Codable {
    var scoreOption: ScoreOption
    var customValue: Int?
}

// Model for each Player
struct Player: Identifiable, Codable {
    var id = UUID()
    var name: String
    var scores: [PlayerScore]
    
    var totalScore: Int {
        return scores.reduce(0) { $0 + ($1.scoreOption.value == -1 ? ($1.customValue ?? 0) : $1.scoreOption.value) }
    }
}

// Formatter for handling number input
let numberFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimum = 0
    return formatter
}()

// Add this struct near the top of the file, after other struct definitions
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// Main view of the app
struct ContentView: View {
    @State private var players: [Player] = []
    @State private var newPlayerName = ""
    @State private var roundCount = 0
    @State private var gameStarted = false  // New state variable
    @State private var showingExportResult = false
    @State private var exportResultMessage = ""
    @State private var documentURL: IdentifiableURL?
    @State private var showingDocumentPicker = false
    @State private var showingEndGameAlert = false
    @State private var gameInProgress = false // Change this to false initially

    @ObservedObject var scoreSettings = ScoreSettings.shared

    let boxWidth: CGFloat = 120
    let boxHeight: CGFloat = 60

    @State private var isKeyboardVisible = false

    var body: some View {
        NavigationView {
            ZStack {  // Wrap the entire content in a ZStack
                Color.clear  // Invisible background to detect taps
                    .contentShape(Rectangle())  // Make the entire area tappable
                    .onTapGesture {
                        hideKeyboard()
                    }
                
                VStack(spacing: 0) {
                    // Title moved to the top
                    Text("GMD Rummy Score")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .shadow(color: .gray.opacity(0.5), radius: 2, x: 1, y: 1)

                    ScrollView {
                        VStack {
                            // Initialize score values section
                            scoreSettingsSection

                            if gameInProgress {
                                // Add new player section
                                addPlayerSection

                                // Players and scores displayed horizontally
                                playersScoresSection

                                // Add Round button
                                if !players.isEmpty {
                                    addRoundButton
                                }
                            } else {
                                // Start New Game button
                                startNewGameButton
                            }
                        }
                        .padding()
                    }

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if gameInProgress {
                            Button(action: exportGame) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.white)
                            }
                            
                            Button(action: {
                                showingEndGameAlert = true
                            }) {
                                Image(systemName: "power")
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
            .alert(isPresented: $showingExportResult) {
                Alert(title: Text("Export Result"), message: Text(exportResultMessage), dismissButton: .default(Text("OK")))
            }
            .sheet(item: $documentURL) { identifiableURL in
                DocumentPicker(url: identifiableURL.url) { success in
                    if success {
                        exportResultMessage = "File exported successfully!"
                    } else {
                        exportResultMessage = "Failed to export file."
                    }
                    showingExportResult = true
                    documentURL = nil
                }
            }
            .alert(isPresented: $showingEndGameAlert) {
                Alert(
                    title: Text("End Game"),
                    message: Text("Are you sure you want to end the game? All scores will be cleared and score boxes will be removed."),
                    primaryButton: .destructive(Text("Continue")) {
                        endGame()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
    }

    // MARK: - UI Components

    // Score Settings Section
    private var scoreSettingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Set Game Rules")
                .font(.headline)
                .padding(.bottom, 5)

            HStack(spacing: 20) {
                scoreSettingField(title: "Drop :", value: $scoreSettings.dropValue)
                scoreSettingField(title: "M-Drop :", value: $scoreSettings.middleDropValue)
                scoreSettingField(title: "Full Count :", value: $scoreSettings.fullCountValue)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }

    // Helper function for score setting fields
    private func scoreSettingField(title: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            TextField(title, value: value, formatter: numberFormatter)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
        }
        .frame(width: 100)
    }

    // Start New Game Button
    private var startNewGameButton: some View {
        Button(action: startNewGame) {
            Text("Start New Game")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .padding(.vertical)
    }

    // Add Player Section
    private var addPlayerSection: some View {
        HStack {
            TextField("Enter player's name", text: $newPlayerName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.leading)
                .autocapitalization(.words)

            Button(action: addPlayer) {
                Text("Add Player")
                    .fontWeight(.semibold)
                    .frame(maxWidth: 100)
                    .padding()
                    .background(newPlayerName.isEmpty ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(newPlayerName.isEmpty)
        }
        .padding(.vertical)
    }

    // Players and Scores Section
    private var playersScoresSection: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 20) {
                ForEach(players.indices, id: \.self) { index in
                    PlayerColumn(player: $players[index], roundCount: roundCount, boxWidth: boxWidth, boxHeight: boxHeight)
                }
            }
            .padding()
        }
    }

    // Add Round Button
    private var addRoundButton: some View {
        Button(action: addRound) {
            Image(systemName: "plus.circle.fill")
                .resizable()
                .frame(width: 44, height: 44)
                .foregroundColor(.blue)
        }
        .padding(.top)
    }

    // MARK: - Functions

    // Add a player function
    private func addPlayer() {
        let newPlayer = Player(name: newPlayerName, scores: Array(repeating: PlayerScore(scoreOption: .zero, customValue: 0), count: roundCount))
        players.append(newPlayer)
        newPlayerName = "" // Clear text field
    }

    // Add a round function
    private func addRound() {
        for index in players.indices {
            players[index].scores.append(PlayerScore(scoreOption: .zero, customValue: 0))
        }
        roundCount += 1
    }

    // Start New Game function
    private func startNewGame() {
        gameInProgress = true
        players = []
        roundCount = 0
    }

    // Modified Export Game function
    private func exportGame() {
        let csvString = generateCSV()
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "RummyScore-\(Date().ISO8601Format()).csv"
        let tempFileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: tempFileURL, atomically: true, encoding: .utf8)
            documentURL = IdentifiableURL(url: tempFileURL)
        } catch {
            exportResultMessage = "Failed to create temporary file: \(error.localizedDescription)"
            showingExportResult = true
        }
    }

    // Generate CSV string
    private func generateCSV() -> String {
        var csvString = "Round,\(players.map { $0.name }.joined(separator: ","))\n"
        
        for round in 0..<roundCount {
            csvString += "\(round + 1),"
            csvString += players.map { player in
                let score = player.scores[round]
                return score.scoreOption == .custom ? "\(score.customValue ?? 0)" : score.scoreOption.rawValue
            }.joined(separator: ",")
            csvString += "\n"
        }
        
        csvString += "Total,\(players.map { "\($0.totalScore)" }.joined(separator: ","))\n"
        
        return csvString
    }

    private func endGame() {
        players.removeAll()
        roundCount = 0
        gameInProgress = false
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// Player Column View
struct PlayerColumn: View {
    @Binding var player: Player
    let roundCount: Int
    let boxWidth: CGFloat
    let boxHeight: CGFloat

    var body: some View {
        VStack {
            playerHeader
            ForEach(0..<roundCount, id: \.self) { round in
                scoreCell(round: round)
            }
        }
        .frame(width: boxWidth)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }

    private var playerHeader: some View {
        VStack(spacing: 5) {
            Text(player.name)
                .font(.headline)
                .multilineTextAlignment(.center)
                .frame(height: boxHeight / 2)
                .background(Color(.systemGray6))
                .cornerRadius(5)
            Text("Total: \(player.totalScore)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(height: boxHeight / 2)
                .background(Color(.systemGray6))
                .cornerRadius(5)
        }
        .frame(height: boxHeight)
    }

    private func scoreCell(round: Int) -> some View {
        let playerScore = Binding(get: {
            player.scores[round]
        }, set: { newValue in
            player.scores[round] = newValue
        })

        return VStack {
            if playerScore.wrappedValue.scoreOption == .custom {
                CustomTextField(
                    text: Binding(
                        get: { String(playerScore.wrappedValue.customValue ?? 0) },
                        set: { newValue in
                            if let intValue = Int(newValue) {
                                var score = playerScore.wrappedValue
                                score.customValue = max(0, intValue)
                                playerScore.wrappedValue = score
                            }
                        }
                    ),
                    keyboardType: .numberPad,
                    onCommit: {
                        // You can add any additional action here if needed
                    },
                    textColor: UIColor(red: 0, green: 0.5, blue: 0, alpha: 1.0) // Dark green color
                )
                .padding(5)
                .frame(width: boxWidth - 10, height: boxHeight)
                .background(solidBackground(for: .custom))
                .cornerRadius(5)
            } else {
                Picker("Select Score", selection: Binding(
                    get: { playerScore.wrappedValue.scoreOption },
                    set: { newValue in
                        var score = playerScore.wrappedValue
                        score.scoreOption = newValue
                        playerScore.wrappedValue = score
                    }
                )) {
                    ForEach(ScoreOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding(5)
                .frame(width: boxWidth - 10, height: boxHeight)
                .background(solidBackground(for: playerScore.wrappedValue.scoreOption))
                .cornerRadius(5)
                .accentColor(Color(red: 0, green: 0.5, blue: 0)) // Dark green color for picker text
            }
        }
    }

    private func solidBackground(for option: ScoreOption) -> Color {
        switch option {
        case .drop:
            return Color(red: 0.9, green: 0.8, blue: 1.0) // Light Purple (previously used for Custom)
        case .middleDrop:
            return Color(red: 1.0, green: 0.9, blue: 0.8) // Light Orange
        case .fullCount:
            return Color(red: 1.0, green: 0.7, blue: 0.7) // Slightly more intense Light Red
        case .game:
            return Color(red: 0.8, green: 1.0, blue: 0.8) // Light Green
        case .zero:
            return Color(red: 0.8, green: 0.9, blue: 1.0) // Light Blue
        case .custom:
            return Color(red: 0.9, green: 0.9, blue: 0.9) // Light Gray (previously used for Drop)
        }
    }
}

// New DocumentPicker view
struct DocumentPicker: UIViewControllerRepresentable {
    let url: URL
    let completion: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [url])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let selectedURL = urls.first else {
                parent.completion(false)
                return
            }

            do {
                if parent.url.startAccessingSecurityScopedResource() {
                    defer { parent.url.stopAccessingSecurityScopedResource() }
                    let data = try Data(contentsOf: parent.url)
                    try data.write(to: selectedURL)
                    parent.completion(true)
                } else {
                    parent.completion(false)
                }
            } catch {
                print("Error saving file: \(error.localizedDescription)")
                parent.completion(false)
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.completion(false)
        }
    }
}

// Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

// New struct for custom text field with a "Done" button
struct CustomTextField: UIViewRepresentable {
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let onCommit: () -> Void
    let textColor: UIColor

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.keyboardType = keyboardType
        textField.delegate = context.coordinator
        textField.textColor = textColor
        
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: "Done", style: .done, target: context.coordinator, action: #selector(Coordinator.doneButtonTapped))
        toolbar.setItems([flexSpace, doneButton], animated: true)
        textField.inputAccessoryView = toolbar
        
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
        uiView.textColor = textColor
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: CustomTextField

        init(_ parent: CustomTextField) {
            self.parent = parent
        }

        @objc func doneButtonTapped() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            parent.onCommit()
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
    }
}