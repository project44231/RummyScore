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
        return scores.reduce(0) { total, score in
            switch score.scoreOption {
            case .custom:
                return total + (score.customValue ?? 0)
            default:
                return total + score.scoreOption.value
            }
        }
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

    let boxWidth: CGFloat = 60
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
                    Text("Rummy Score Card")
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
            .sheet(item: $documentURL) { document in
                DocumentPicker(url: document.url) { success in
                    if success {
                        exportResultMessage = "File exported successfully!"
                    } else {
                        exportResultMessage = "File export was cancelled or failed."
                    }
                    showingExportResult = true
                    showingDocumentPicker = false
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
        .onAppear(perform: loadGameState)
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
            VStack {
                HStack(spacing: 20) {
                    ForEach(players.indices, id: \.self) { index in
                        PlayerColumn(player: $players[index], roundCount: roundCount, boxWidth: boxWidth, boxHeight: boxHeight)
                    }
                }
                .padding()
            }
            .background(Color.white) // Add a white background
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.blue, lineWidth: 3)
            )
            .padding() // Add some padding around the bordered area
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
        saveGameState()
    }

    // Add a round function
    private func addRound() {
        for index in players.indices {
            players[index].scores.append(PlayerScore(scoreOption: .zero, customValue: 0))
        }
        roundCount += 1
        saveGameState()
    }

    // Start New Game function
    private func startNewGame() {
        gameInProgress = true
        players = []
        roundCount = 0
        saveGameState()
    }

    // Modified Export Game function
    private func exportGame() {
        let csvString = generateCSV()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy_MM_dd_HH_mm_ss"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: -5 * 3600) // EST is GMT-5
        let timestamp = dateFormatter.string(from: Date())
        
        let fileName = "RummyScoreCard_\(timestamp)_EST.csv"
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: tempFileURL, atomically: true, encoding: .utf8)
            showingDocumentPicker = true
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
        saveGameState()
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    public func saveGameState() {
        let encoder = JSONEncoder()
        if let encodedPlayers = try? encoder.encode(players) {
            UserDefaults.standard.set(encodedPlayers, forKey: "players")
        }
        UserDefaults.standard.set(roundCount, forKey: "roundCount")
        UserDefaults.standard.set(gameInProgress, forKey: "gameInProgress")
        
        // Save score settings
        UserDefaults.standard.set(scoreSettings.dropValue, forKey: "dropValue")
        UserDefaults.standard.set(scoreSettings.middleDropValue, forKey: "middleDropValue")
        UserDefaults.standard.set(scoreSettings.fullCountValue, forKey: "fullCountValue")
    }

    private func loadGameState() {
        if let savedPlayers = UserDefaults.standard.data(forKey: "players") {
            let decoder = JSONDecoder()
            if let decodedPlayers = try? decoder.decode([Player].self, from: savedPlayers) {
                players = decodedPlayers
            }
        }
        roundCount = UserDefaults.standard.integer(forKey: "roundCount")
        gameInProgress = UserDefaults.standard.bool(forKey: "gameInProgress")
        
        // Load score settings
        scoreSettings.dropValue = UserDefaults.standard.integer(forKey: "dropValue")
        scoreSettings.middleDropValue = UserDefaults.standard.integer(forKey: "middleDropValue")
        scoreSettings.fullCountValue = UserDefaults.standard.integer(forKey: "fullCountValue")
    }
}

// Player Column View
struct PlayerColumn: View {
    @Binding var player: Player
    let roundCount: Int
    let boxWidth: CGFloat
    let boxHeight: CGFloat
    
    @ObservedObject var scoreSettings = ScoreSettings.shared
    @State private var isEditingCustomValue: [Int: Bool] = [:]
    @FocusState private var focusedField: Int?

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
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            ZStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 30, height: 30)
                Text("\(player.totalScore)")
                    .font(.caption)
                    .foregroundColor(.white)
                    .fontWeight(.bold)
            }
        }
        .frame(height: boxHeight)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(5)
    }

    private func scoreCell(round: Int) -> some View {
        Group {
            if player.scores[round].scoreOption == .custom && (isEditingCustomValue[round] ?? false) {
                TextField("Custom", text: Binding(
                    get: { "\(player.scores[round].customValue ?? 0)" },
                    set: { newValue in
                        if let value = Int(newValue) {
                            player.scores[round].customValue = value
                            saveGameState()
                        }
                    }
                ), onCommit: {
                    isEditingCustomValue[round] = false
                })
                .keyboardType(.numberPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: boxWidth - 10, height: boxHeight - 10)
                .focused($focusedField, equals: round)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.focusedField = round
                    }
                }
            } else {
                Menu {
                    Picker("Select Score", selection: Binding(
                        get: { player.scores[round].scoreOption },
                        set: { newValue in
                            player.scores[round].scoreOption = newValue
                            if newValue == .custom {
                                isEditingCustomValue[round] = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    self.focusedField = round
                                }
                            } else {
                                player.scores[round].customValue = nil
                            }
                            saveGameState()
                        }
                    )) {
                        ForEach(ScoreOption.allCases, id: \.self) { option in
                            Text(optionDisplayText(for: option)).tag(option)
                        }
                    }
                } label: {
                    Text(optionValueText(for: player.scores[round].scoreOption, customValue: player.scores[round].customValue))
                        .foregroundColor(.black)
                        .frame(width: boxWidth - 20, height: boxHeight - 10)
                        .background(solidBackground(for: player.scores[round].scoreOption))
                        .cornerRadius(5)
                }
            }
        }
        .frame(width: boxWidth - 10, height: boxHeight)
    }

    private func optionDisplayText(for option: ScoreOption) -> String {
        switch option {
        case .drop:
            return "Drop (\(ScoreSettings.shared.dropValue))"
        case .middleDrop:
            return "M-Drop (\(ScoreSettings.shared.middleDropValue))"
        case .fullCount:
            return "Full Count (\(ScoreSettings.shared.fullCountValue))"
        default:
            return option.rawValue
        }
    }

    private func optionValueText(for option: ScoreOption, customValue: Int?) -> String {
        switch option {
        case .drop:
            return "\(ScoreSettings.shared.dropValue)"
        case .middleDrop:
            return "\(ScoreSettings.shared.middleDropValue)"
        case .fullCount:
            return "\(ScoreSettings.shared.fullCountValue)"
        case .zero, .game:
            return "0"
        case .custom:
            return "\(customValue ?? 0)"
        }
    }

    private func solidBackground(for option: ScoreOption) -> Color {
        switch option {
        case .drop:
            return Color(red: 0.9, green: 0.9, blue: 0.9) // Custom light gray
        case .middleDrop:
            return Color(red: 1.0, green: 0.9, blue: 0.8) // Light Orange
        case .fullCount:
            return Color(red: 1.0, green: 0.7, blue: 0.7) // Light Red
        case .game:
            return Color(red: 0.8, green: 1.0, blue: 0.8) // Light Green
        case .zero:
            return Color(red: 0.8, green: 0.9, blue: 1.0) // Light Blue
        case .custom:
            return Color(red: 0.9, green: 0.9, blue: 0.9) // Light Gray
        }
    }

    private func saveGameState() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController,
           let contentView = rootViewController.view?.subviews.first(where: { $0 is ContentView }) as? ContentView {
            contentView.saveGameState()
        }
    }
}

// New DocumentPicker view
struct DocumentPicker: UIViewControllerRepresentable {
    let url: URL
    let completion: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
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
            parent.completion(true)
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
