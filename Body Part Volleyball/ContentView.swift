

import SwiftUI
import Combine


// MARK: - Game Data Models
enum BallType: String, CaseIterable {
    case classic = "Classic"
    case shooter = "Shooter"
    case power = "Power"
    case golden = "Golden"
    
    var icon: String {
        switch self {
        case .classic: return "volleyball"
        case .shooter: return "basketball"
        case .power: return "football"
        case .golden: return "sun.max"
        }
    }
    
    var color: Color {
        switch self {
        case .classic: return .orange
        case .shooter: return .red
        case .power: return .purple
        case .golden: return .yellow
        }
    }
    
    var scoreMultiplier: Int {
        switch self {
        case .classic: return 1
        case .shooter: return 2
        case .power: return 3
        case .golden: return 5
        }
    }
    
    var speedMultiplier: CGFloat {
        switch self {
        case .classic: return 1.0
        case .shooter: return 1.3
        case .power: return 0.8
        case .golden: return 1.5
        }
    }
}

struct Level {
    let number: Int
    let name: String
    let time: Int
    let targetScore: Int
    let difficulty: CGFloat
    let color: Color
    
    static let levels: [Level] = [
        Level(number: 1, name: "Beginner", time: 60, targetScore: 5, difficulty: 1.0, color: .green),
        Level(number: 2, name: "Rookie", time: 90, targetScore: 15, difficulty: 1.2, color: .blue),
        Level(number: 3, name: "Pro", time: 120, targetScore: 30, difficulty: 1.5, color: .orange),
        Level(number: 4, name: "Expert", time: 150, targetScore: 50, difficulty: 1.8, color: .purple),
        Level(number: 5, name: "Master", time: 180, targetScore: 75, difficulty: 2.2, color: .red),
        Level(number: 6, name: "Legend", time: 210, targetScore: 100, difficulty: 2.8, color: .yellow)
    ]
}

// MARK: - Game Manager
class GameManager: ObservableObject {
    @Published var currentScreen: GameScreen = .mainMenu
    @Published var score = 0
    @Published var highScore = 0
    @Published var gameTime = 60
    @Published var isGameActive = false
    @Published var gameTimer: Timer?
    @Published var selectedBall: BallType = .classic
    @Published var currentLevel: Level = Level.levels[0]
    @Published var unlockedLevels: Int = 1
    @Published var showLevelComplete = false
    
    enum GameScreen {
        case mainMenu, levelSelect, ballSelect, game, gameOver
    }
    
    init() {
        highScore = UserDefaults.standard.integer(forKey: "HighScore")
        unlockedLevels = UserDefaults.standard.integer(forKey: "UnlockedLevels")
        if unlockedLevels == 0 { unlockedLevels = 1 }
        
        // Load selected ball
        if let savedBall = UserDefaults.standard.string(forKey: "SelectedBall"),
           let ballType = BallType(rawValue: savedBall) {
            selectedBall = ballType
        }
    }
    
    
    func addScore(points: Int) {
        let multipliedPoints = points * selectedBall.scoreMultiplier
        score += multipliedPoints
        
        // Check if level target is achieved
        if score >= currentLevel.targetScore && !showLevelComplete {
            showLevelComplete = true
            
            // Unlock next level if applicable
            if currentLevel.number < Level.levels.count && currentLevel.number >= unlockedLevels {
                unlockedLevels = currentLevel.number + 1
                UserDefaults.standard.set(unlockedLevels, forKey: "UnlockedLevels")
            }
            
            // Update high score
            if score > highScore {
                highScore = score
                UserDefaults.standard.set(highScore, forKey: "HighScore")
            }
        }
    }
    

    
    func selectBall(_ ball: BallType) {
        selectedBall = ball
        UserDefaults.standard.set(ball.rawValue, forKey: "SelectedBall")
    }
    
    
    func startGame(level: Level) {
        currentLevel = level
        score = 0
        gameTime = level.time
        isGameActive = true
        currentScreen = .game
        showLevelComplete = false
        
        // Invalidate any existing timer first
        gameTimer?.invalidate()
        gameTimer = nil
        
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.gameTime > 0 {
                self.gameTime -= 1
            } else {
                self.endGame()
            }
        }
    }
    
    func endGame() {
        // Prevent multiple calls to endGame
        guard isGameActive else { return }
        
        isGameActive = false
        gameTimer?.invalidate()
        gameTimer = nil
        
        if score > highScore {
            highScore = score
            UserDefaults.standard.set(highScore, forKey: "HighScore")
        }
        
        // Add a small delay to ensure game is properly stopped
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.currentScreen = .gameOver
        }
    }
    
    func navigateToScreen(_ screen: GameScreen) {
        // Stop game properly before navigation
        if isGameActive {
            pauseGame()
        }
        
        // Small delay to ensure game is stopped
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.currentScreen = screen
        }
    }
    
    func pauseGame() {
        isGameActive = false
        gameTimer?.invalidate()
        gameTimer = nil
    }
    
    func resetGame() {
        score = 0
        showLevelComplete = false
        isGameActive = false
        gameTimer?.invalidate()
        gameTimer = nil
    }
    
}

// MARK: - Enhanced Game Engine
class GameEngine: ObservableObject {
    @Published var ball = Ball()
    @Published var opponent = Opponent()
    @Published var character = WobbleCharacter()
    @Published var shouldAddScore = false
    @Published var showHitEffect = false
    @Published var hitEffectPosition: CGPoint = .zero
    @Published var comboCount = 0
    @Published var lastHitTime = Date()
    
    private var physicsTimer: Timer?
    private let screenWidth = UIScreen.main.bounds.width
    private let screenHeight = UIScreen.main.bounds.height
    
    weak var gameManager: GameManager?
    
    struct Ball {
        var position: CGPoint = CGPoint(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
        var velocity: CGVector = CGVector(dx: 3, dy: -4)
        var isActive = true
        var lastHitBy: String = ""
        var hasScored = false
        var hitCount = 0
    }
    
    struct Opponent {
        var position: CGPoint = CGPoint(x: UIScreen.main.bounds.width / 2, y: 100)
        var targetX: CGFloat = UIScreen.main.bounds.width / 2
        var reactionTime: CGFloat = 0.6
        var speed: CGFloat = 3.0
        var difficulty: CGFloat = 1.0
    }
    
    struct WobbleCharacter {
        var leftHandPosition: CGPoint = CGPoint(x: 100, y: 500)
        var rightHandPosition: CGPoint = CGPoint(x: 300, y: 500)
        var headPosition: CGPoint = CGPoint(x: 200, y: 400)
        var leftHandWobble: CGFloat = 0
        var rightHandWobble: CGFloat = 0
        var headWobble: CGFloat = 0
        var isLeftHandReady = true
        var isRightHandReady = true
        var isHeadReady = true
        
        let defaultLeftHandPosition = CGPoint(x: 100, y: 500)
        let defaultRightHandPosition = CGPoint(x: 300, y: 500)
        let defaultHeadPosition = CGPoint(x: 200, y: 400)
    }
    
    func setGameManager(_ manager: GameManager) {
        self.gameManager = manager
        updateDifficulty()
    }
    
    func updateDifficulty() {
        guard let manager = gameManager else { return }
        opponent.difficulty = manager.currentLevel.difficulty
        opponent.speed = 3.0 * manager.currentLevel.difficulty * 0.8
    }
    
    func startGame() {
        // Reset everything before starting
        resetBall()
        updateDifficulty()
        resetCharacter()
        comboCount = 0
        
        // Stop any existing timer
        physicsTimer?.invalidate()
        physicsTimer = nil
        
        physicsTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            guard let self = self, self.gameManager?.isGameActive == true else { return }
            self.updatePhysics()
        }
    }
    
    func stopGame() {
        physicsTimer?.invalidate()
        physicsTimer = nil
        comboCount = 0
    }

    func resetBall() {
        let startX = CGFloat.random(in: 100...(screenWidth - 100))
        ball.position = CGPoint(x: startX, y: 150)
        
        let randomDX = CGFloat.random(in: -4...4)
        let speedMultiplier = gameManager?.selectedBall.speedMultiplier ?? 1.0
        ball.velocity = CGVector(dx: randomDX * speedMultiplier, dy: 4 * speedMultiplier)
        ball.lastHitBy = "opponent"
        ball.hasScored = false
        ball.hitCount = 0
    }
    
    func resetCharacter() {
        character.leftHandPosition = character.defaultLeftHandPosition
        character.rightHandPosition = character.defaultRightHandPosition
        character.headPosition = character.defaultHeadPosition
        character.isLeftHandReady = true
        character.isRightHandReady = true
        character.isHeadReady = true
    }
    
    func updatePhysics() {
        guard gameManager?.isGameActive == true else { return }
        
        // Add slight gravity
        ball.velocity.dy += 0.05
        
        // Update ball position with ball type speed multiplier
        let speedMultiplier = gameManager?.selectedBall.speedMultiplier ?? 1.0
        ball.position.x += ball.velocity.dx * speedMultiplier
        ball.position.y += ball.velocity.dy * speedMultiplier
        
        // Ball collisions with walls
        if ball.position.x <= 20 {
            ball.position.x = 20
            ball.velocity.dx *= -0.9
        } else if ball.position.x >= screenWidth - 20 {
            ball.position.x = screenWidth - 20
            ball.velocity.dx *= -0.9
        }
        
        // SCORING LOGIC
        if ball.position.y <= 50 && !ball.hasScored {
            if ball.lastHitBy == "player" {
                shouldAddScore = true
                ball.hasScored = true
            }
            resetBall()
        }
        
        if ball.position.y >= screenHeight - 80 && !ball.hasScored {
            if ball.lastHitBy == "opponent" {
                ball.hasScored = true
            }
            resetBall()
        }
        
        // Update opponent AI with difficulty
        updateOpponent()
        
        // Check collisions with character body parts
        checkCharacterCollisions()
        
        // Update combo
        updateCombo()
    }
    
    func updateOpponent() {
        let predictionX = ball.position.x + ball.velocity.dx * 10
        let errorRange = 50 / opponent.difficulty
        let error = CGFloat.random(in: -errorRange...errorRange)
        opponent.targetX = predictionX + error
        
        opponent.targetX = max(50, min(opponent.targetX, screenWidth - 50))
        
        let diff = opponent.targetX - opponent.position.x
        opponent.position.x += diff * 0.1 * opponent.difficulty
        
        let hitZone = CGRect(x: opponent.position.x - 45, y: 80, width: 90, height: 40)
        if hitZone.contains(ball.position) && ball.velocity.dy > 0 && ball.lastHitBy != "opponent" {
            let targetX = CGFloat.random(in: 100...(screenWidth - 100))
            let dx = (targetX - ball.position.x) * 0.1 * opponent.difficulty
            let dy = -8 * opponent.difficulty
            ball.velocity = CGVector(dx: dx, dy: dy)
            ball.lastHitBy = "opponent"
            showHitEffect(at: ball.position)
        }
    }
    
    func checkCharacterCollisions() {
        let ballRadius: CGFloat = 20
        let baseHitStrength: CGFloat = 12
        
        // Check left hand collision
        let leftHandDistance = distance(ball.position, character.leftHandPosition)
        if leftHandDistance < 40 && character.isLeftHandReady && ball.lastHitBy != "player" {
            hitBall(with: CGVector(dx: -baseHitStrength + character.leftHandWobble * 0.5, dy: -baseHitStrength))
            ball.lastHitBy = "player"
            ball.hitCount += 1
            animateLeftHandHit()
            showHitEffect(at: ball.position)
        }
        
        // Check right hand collision
        let rightHandDistance = distance(ball.position, character.rightHandPosition)
        if rightHandDistance < 40 && character.isRightHandReady && ball.lastHitBy != "player" {
            hitBall(with: CGVector(dx: baseHitStrength + character.rightHandWobble * 0.5, dy: -baseHitStrength))
            ball.lastHitBy = "player"
            ball.hitCount += 1
            animateRightHandHit()
            showHitEffect(at: ball.position)
        }
        
        // Check head collision
        let headDistance = distance(ball.position, character.headPosition)
        if headDistance < 35 && character.isHeadReady && ball.lastHitBy != "player" {
            hitBall(with: CGVector(dx: character.headWobble * 0.8, dy: -baseHitStrength * 1.3))
            ball.lastHitBy = "player"
            ball.hitCount += 1
            animateHeadHit()
            showHitEffect(at: ball.position)
        }
    }
    
    func hitBall(with force: CGVector) {
        let speedMultiplier = gameManager?.selectedBall.speedMultiplier ?? 1.0
        ball.velocity = CGVector(dx: force.dx * speedMultiplier, dy: force.dy * speedMultiplier)
        
        ball.velocity.dx += CGFloat.random(in: -1.5...1.5)
        ball.velocity.dy += CGFloat.random(in: -1...1)
        
        let maxSpeed: CGFloat = 15 * speedMultiplier
        let currentSpeed = sqrt(ball.velocity.dx * ball.velocity.dx + ball.velocity.dy * ball.velocity.dy)
        if currentSpeed > maxSpeed {
            let scale = maxSpeed / currentSpeed
            ball.velocity.dx *= scale
            ball.velocity.dy *= scale
        }
        
        // Update combo
        comboCount += 1
        lastHitTime = Date()
    }
    
    func updateCombo() {
        if Date().timeIntervalSince(lastHitTime) > 2.0 && comboCount > 0 {
            comboCount = 0
        }
    }
    
    func showHitEffect(at position: CGPoint) {
        hitEffectPosition = position
        showHitEffect = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showHitEffect = false
        }
    }
    
    // MARK: - Hand Movement Functions
    func moveLeftHand(to newPosition: CGPoint) {
        guard character.isLeftHandReady else { return }
        
        let boundedX = max(50, min(newPosition.x, screenWidth / 2 - 30))
        let boundedY = max(screenHeight / 2, min(newPosition.y, screenHeight - 100))
        
        character.leftHandPosition = CGPoint(x: boundedX, y: boundedY)
    }
    
    func moveRightHand(to newPosition: CGPoint) {
        guard character.isRightHandReady else { return }
        
        let boundedX = max(screenWidth / 2 + 30, min(newPosition.x, screenWidth - 50))
        let boundedY = max(screenHeight / 2, min(newPosition.y, screenHeight - 100))
        
        character.rightHandPosition = CGPoint(x: boundedX, y: boundedY)
    }
    
    func resetHandPositions() {
        character.leftHandPosition = character.defaultLeftHandPosition
        character.rightHandPosition = character.defaultRightHandPosition
    }
    
    func animateLeftHandHit() {
        character.isLeftHandReady = false
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            character.leftHandWobble = CGFloat.random(in: -10...10)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                self.character.leftHandWobble = 0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            self.character.isLeftHandReady = true
        }
    }
    
    func animateRightHandHit() {
        character.isRightHandReady = false
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            character.rightHandWobble = CGFloat.random(in: -10...10)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                self.character.rightHandWobble = 0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            self.character.isRightHandReady = true
        }
    }
    
    func animateHeadHit() {
        character.isHeadReady = false
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            character.headWobble = CGFloat.random(in: -15...15)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                self.character.headWobble = 0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            self.character.isHeadReady = true
        }
    }
    
    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        return sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2))
    }
}

// MARK: - Enhanced Splash View
struct SplashView: View {
    @State private var isActive = false
    @State private var size = 0.8
    @State private var opacity = 0.5
    @State private var rotation = 0.0
    @State private var scaleEffect = 1.0
    
    var body: some View {
        if isActive {
            ContentView()
        } else {
            ZStack {
                // Animated Gradient Background
                AnimatedGradientBackground()
                
                VStack {
                    // Animated Volleyball Icon
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [.white, .orange, .red]),
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 60
                                )
                            )
                            .frame(width: 200, height: 200)
                            .rotationEffect(.degrees(rotation))
                            .scaleEffect(scaleEffect)
                            .shadow(color: .orange, radius: 20)
                        
                        Image(systemName: "figure.volleyball")
                            .font(.system(size: 150))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(-rotation))
                    }
                
                    
                    Text("Body Part\nVolleyball")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .blue, radius: 10)
                        .multilineTextAlignment(.center)
                    
                    Text("Control the Wobble!")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.yellow)
                        .padding(.top, 5)
                        .shadow(color: .black, radius: 5)
                    
                    // Loading Dots
                    HStack(spacing: 8) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.white)
                                .frame(width: 10, height: 10)
                                .scaleEffect(size)
                                .animation(
                                    Animation.easeInOut(duration: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                    value: size
                                )
                        }
                    }
                    .padding(.top, 30)
                }
                .scaleEffect(size)
                .opacity(opacity)
            }
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeIn(duration: 1.2)) {
                    self.size = 1.0
                    self.opacity = 1.0
                }
                
                withAnimation(Animation.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    self.rotation = 360
                }
                
                withAnimation(Animation.easeInOut(duration: 1.0).repeatForever()) {
                    self.scaleEffect = 1.1
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation {
                        self.isActive = true
                    }
                }
            }
        }
    }
}

struct AnimatedGradientBackground: View {
    @State private var gradientStart = UnitPoint(x: 0, y: 0)
    @State private var gradientEnd = UnitPoint(x: 1, y: 1)
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.blue,
                Color.purple,
                Color.orange,
                Color.pink
            ]),
            startPoint: gradientStart,
            endPoint: gradientEnd
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                self.gradientStart = UnitPoint(x: 1, y: 1)
                self.gradientEnd = UnitPoint(x: 0, y: 0)
            }
        }
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var gameManager = GameManager()
    
    var body: some View {
        ZStack {
            switch gameManager.currentScreen {
            case .mainMenu:
                MainMenuView()
            case .levelSelect:
                LevelSelectView()
            case .ballSelect:
                BallSelectView()
            case .game:
                GameView()
                    .onDisappear {
                        gameManager.pauseGame()
                    }
            case .gameOver:
                GameOverView()
            }
        }
        .environmentObject(gameManager)
    }
}

// MARK: - Enhanced Main Menu View
struct MainMenuView: View {
    @EnvironmentObject var gameManager: GameManager
    
    var body: some View {
        ZStack {
            GameBackground()
            
            ScrollView {
                VStack(spacing: 40) {
                    // Header
                    VStack(spacing: 20) {
                        Image(systemName: "figure.volleyball")
                            .font(.system(size: 80))
                            .foregroundColor(.white)
                            .shadow(color: .blue, radius: 10)
                    
                        
                        Text("Body Part\nVolleyball")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .blue, radius: 10)
                            .multilineTextAlignment(.center)
                        
                        Text("Control the Wobble!")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.yellow)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                    
                    // Stats
                    HStack(spacing: 20) {
                        StatBadge(icon: "trophy.fill", value: "\(gameManager.highScore)", color: .yellow, title: "High Score")
                        StatBadge(icon: "star.fill", value: "\(gameManager.unlockedLevels)/6", color: .green, title: "Levels")
                        StatBadge(icon: gameManager.selectedBall.icon, value: "x\(gameManager.selectedBall.scoreMultiplier)", color: gameManager.selectedBall.color, title: "Ball")
                    }
                    .padding(.horizontal)
                    
                    // Menu Options - Icon Grid
                    VStack(spacing: 30) {
                        Text("Quick Actions")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.bottom, 10)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 25) {
                            MenuIconOption(
                                title: "Play Game",
                                subtitle: "Start playing",
                                icon: "play.circle.fill",
                                iconColor: .green,
                                badge: nil
                            ) {
                                gameManager.currentScreen = .levelSelect
                            }
                            
                            MenuIconOption(
                                title: "Select Ball",
                                subtitle: "Choose ball type",
                                icon: "volleyball.fill",
                                iconColor: .orange,
                                badge: nil
                            ) {
                                gameManager.currentScreen = .ballSelect
                            }
                            
                       
                        }
                        .padding(.horizontal, 20)
                    }
          
                    
                    Spacer(minLength: 50)
                }
            }
        }
    }
}

struct MenuIconOption: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let badge: String?
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Icon with background
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.2))
                        .frame(width: 70, height: 70)
                    
                    Circle()
                        .stroke(iconColor.opacity(0.3), lineWidth: 2)
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(iconColor)
                    
                    // Badge if exists
                    if let badge = badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 25, y: -25)
                    }
                }
                
                // Text content
                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.95 : isHovered ? 1.05 : 1.0)
            .shadow(
                color: isHovered ? iconColor.opacity(0.3) : .clear,
                radius: isHovered ? 10 : 0,
                x: 0,
                y: isHovered ? 5 : 0
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = pressing
            }
        }, perform: {})
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}


// Enhanced StatBadge to match new design
struct StatBadge: View {
    let icon: String
    let value: String
    let color: Color
    let title: String
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.black)
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Level Select View
struct LevelSelectView: View {
    @EnvironmentObject var gameManager: GameManager
    
    var body: some View {
        ZStack {
            GameBackground()
            
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 8) {
                    Text("Choose Level to Start")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
                    
                    Text("Choose your challenge!")
                        .font(.callout)
                        .foregroundColor(.yellow)
                        .fontWeight(.medium)
                }
                .padding(.top, 40)
                
                // Levels Grid with ScrollView
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                        ForEach(Level.levels, id: \.number) { level in
                            LevelCard(level: level, isUnlocked: level.number <= gameManager.unlockedLevels) {
                                if level.number <= gameManager.unlockedLevels {
                                    gameManager.startGame(level: level)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Back Button
                Button("Go Back") {
                    gameManager.currentScreen = .mainMenu
                }
                .gameButton(backgroundColor: .gray.opacity(0.8))
                .padding(.bottom, 20)
            }
        }
    }
}

struct LevelCard: View {
    let level: Level
    let isUnlocked: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Level Number with Icon
                ZStack {
                    Circle()
                        .fill(isUnlocked ? level.color : Color.gray.opacity(0.5))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .stroke(isUnlocked ? level.color : Color.gray, lineWidth: 2)
                                .blur(radius: 1)
                                .offset(x: 0, y: 1)
                                .mask(Circle().fill(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)))
                        )
                    
                    if isUnlocked {
                        Text("\(level.number)")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                // Level Info
                VStack(spacing: 2) {
                    Text(level.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(level.time)s")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "target")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(level.targetScore)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    // Card background
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.black.opacity(0.7),
                                    Color.black.opacity(0.4)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    // Shine effect for unlocked levels
                    if isUnlocked {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        level.color.opacity(0.8),
                                        level.color.opacity(0.2)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    }
                }
            )
            .overlay(
                // Lock overlay for locked levels
                Group {
                    if !isUnlocked {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.6))
                    }
                }
            )
            .cornerRadius(16)
            .shadow(
                color: isUnlocked ? level.color.opacity(0.3) : Color.black.opacity(0.3),
                radius: isUnlocked ? 8 : 4,
                x: 0,
                y: isUnlocked ? 4 : 2
            )
            .scaleEffect(isUnlocked ? 1.0 : 0.95)
        }
        .disabled(!isUnlocked)
        .buttonStyle(ScaleButtonStyle())
    }
}

// Custom button style for scale effect
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}



// MARK: - Ball Select View
struct BallSelectView: View {
    @EnvironmentObject var gameManager: GameManager
    
    var body: some View {
        ZStack {
            GameBackground()
            
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("Select VolleyBall")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
                    
                    Text("Each ball has unique properties!")
                        .font(.callout)
                        .foregroundColor(.yellow)
                        .fontWeight(.medium)
                }
                .padding(.top, 40)
                
                // Compact Balls Grid
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                        ForEach(BallType.allCases, id: \.self) { ballType in
                            BallOption(ballType: ballType, isSelected: gameManager.selectedBall == ballType) {
                                gameManager.selectBall(ballType)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 30)
                }
                
                // Selected Ball Stats
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: gameManager.selectedBall.icon)
                            .font(.title3)
                            .foregroundColor(gameManager.selectedBall.color)
                        
                        Text(gameManager.selectedBall.rawValue)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    HStack(spacing: 20) {
                        StatPill(icon: "star.fill", value: "x\(gameManager.selectedBall.scoreMultiplier)", color: .green)
                        StatPill(icon: "gauge", value: "\(String(format: "%.1f", gameManager.selectedBall.speedMultiplier))x", color: .orange)
                        StatPill(icon: "info.circle.fill", value: "Unique", color: .blue)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(gameManager.selectedBall.color.opacity(0.3), lineWidth: 2)
                        )
                )
                .padding(.horizontal, 20)
                
                // Back Button
                Button("Go Back") {
                    gameManager.currentScreen = .mainMenu
                }
                .gameButton(backgroundColor: .gray.opacity(0.8))
                .padding(.bottom, 20)
            }
        }
    }
}

struct BallOption: View {
    let ballType: BallType
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Ball Icon with Selection Indicator
                ZStack {
                    Circle()
                        .fill(ballType.color.opacity(0.9))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .stroke(ballType.color, lineWidth: 2)
                                .blur(radius: 1)
                                .offset(x: 0, y: 1)
                                .mask(Circle().fill(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)))
                        )
                    
                    Image(systemName: ballType.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                    
                    // Selection Ring
                    if isSelected {
                        Circle()
                            .stroke(ballType.color, lineWidth: 3)
                            .frame(width: 70, height: 70)
                    }
                }
                
                // Ball Name
                Text(ballType.rawValue)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                // Multiplier Badge
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.white)
                    
                    Text("x\(ballType.scoreMultiplier)")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(ballType.color)
                )
            }
            .padding(12)
            .background(
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.6),
                                    Color.black.opacity(0.3)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    // Selected State
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(ballType.color, lineWidth: 2)
                            .shadow(color: ballType.color.opacity(0.5), radius: 8, x: 0, y: 0)
                    }
                }
            )
            .scaleEffect(isHovered ? 1.08 : (isSelected ? 1.05 : 1.0))
            .shadow(
                color: isSelected ? ballType.color.opacity(0.4) : .black.opacity(0.2),
                radius: isSelected ? 8 : 4,
                x: 0,
                y: isSelected ? 4 : 2
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

struct StatPill: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.2))
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Updated Game View
struct GameView: View {
    @EnvironmentObject var gameManager: GameManager
    @StateObject private var gameEngine = GameEngine()
    @State private var showTutorial = true
    @State private var gameStarted = false
    @State private var showControlHints = true
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            let isSmallDevice = screenHeight < 700
            
            ZStack {
                GameBackground()
                
                VStack(spacing: 0) {
                    // Game UI Header
                    HStack {
                        Button(action: {
                            // Use new navigation method
                            gameManager.navigateToScreen(.levelSelect)
                        }) {
                            Image(systemName: "chevron.left")
                                .font(isSmallDevice ? .body : .title2)
                                .foregroundColor(.white)
                                .padding(isSmallDevice ? 8 : 12)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(8)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 2) {
                            Text("\(gameManager.score)")
                                .font(.system(size: isSmallDevice ? 24 : 30, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .black, radius: 2)
                            
                            Text("SCORE")
                                .font(isSmallDevice ? .caption2 : .caption)
                                .fontWeight(.bold)
                                .foregroundColor(.yellow)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 2) {
                            Text("\(gameManager.gameTime)")
                                .font(.system(size: isSmallDevice ? 20 : 24, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .black, radius: 2)
                            
                            Text("TIME")
                                .font(isSmallDevice ? .caption2 : .caption)
                                .fontWeight(.bold)
                                .foregroundColor(gameManager.gameTime <= 10 ? .red : .green)
                        }
                        .padding(.horizontal, isSmallDevice ? 8 : 12)
                        .padding(.vertical, isSmallDevice ? 6 : 8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        
                        Spacer()
                        
                        VStack(spacing: 2) {
                            Text("Level \(gameManager.currentLevel.number)")
                                .font(.system(size: isSmallDevice ? 14 : 16, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Target: \(gameManager.currentLevel.targetScore)")
                                .font(isSmallDevice ? .caption2 : .caption)
                                .foregroundColor(.yellow)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, isSmallDevice ? 30 : 50)
                    
                    // Ball Type Indicator
                    HStack {
                        Image(systemName: gameManager.selectedBall.icon)
                            .foregroundColor(gameManager.selectedBall.color)
                        Text("\(gameManager.selectedBall.rawValue) Ball")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Text("x\(gameManager.selectedBall.scoreMultiplier)")
                            .font(.caption2)
                            .foregroundColor(.green)
                            .padding(4)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(4)
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(10)
                    .padding(.top, 5)
                    
                    Spacer()
                    
                    // Game Arena
                    ZStack {
                        NetView()
                        
                        WobbleCharacter(gameEngine: gameEngine, screenHeight: screenHeight)
                            .gesture(
                                SimultaneousGesture(
                                    DragGesture()
                                        .onChanged { value in
                                            if value.startLocation.x < screenWidth / 2 {
                                                gameEngine.moveLeftHand(to: value.location)
                                            }
                                        },
                                    DragGesture()
                                        .onChanged { value in
                                            if value.startLocation.x > screenWidth / 2 {
                                                gameEngine.moveRightHand(to: value.location)
                                            }
                                        }
                                )
                            )
                        
                        VolleyballView(ball: gameEngine.ball, ballType: gameManager.selectedBall)
                        
                        OpponentView(opponent: gameEngine.opponent)
                        
                        if gameEngine.showHitEffect {
                            HitEffectView(position: gameEngine.hitEffectPosition, color: gameManager.selectedBall.color)
                        }
                        
                        if showControlHints && !gameStarted {
                            ControlGuidesView()
                        }
                        
                        // Combo Display
                        if gameEngine.comboCount > 1 {
                            VStack {
                                Text("COMBO x\(gameEngine.comboCount)!")
                                    .font(.system(size: 20, weight: .black, design: .rounded))
                                    .foregroundColor(.yellow)
                                    .shadow(color: .black, radius: 5)
                                
                                Text("+\(gameEngine.comboCount) points")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            .padding(10)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                            .offset(y: -100)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    Spacer()
                }
                
                // Tutorial Popup - Only show if game hasn't started
                if showTutorial && !gameStarted {
                    TutorialPopupView(
                        isShowing: $showTutorial,
                        gameStarted: $gameStarted,
                        showControlHints: $showControlHints,
                        gameEngine: gameEngine,
                        screenWidth: screenWidth,
                        isSmallDevice: isSmallDevice
                    )
                }
                
                // Level Complete Popup
                if gameManager.showLevelComplete {
                    LevelCompletePopup()
                }
            }
        }
        .onAppear {
            gameEngine.setGameManager(gameManager)
            // DON'T start game automatically here
            // Game will start only when user clicks "Start Game" in tutorial
        }
        .onDisappear {
            // Always stop game when view disappears
            gameEngine.stopGame()
            gameManager.pauseGame()
        }
        .onReceive(gameEngine.$shouldAddScore) { shouldAdd in
            if shouldAdd {
                let points = 1 + (gameEngine.comboCount > 1 ? gameEngine.comboCount : 0)
                gameManager.addScore(points: points)
                gameEngine.shouldAddScore = false
            }
        }
    }
}

// MARK: - Enhanced Volleyball View with Different Ball Types
struct VolleyballView: View {
    let ball: GameEngine.Ball
    let ballType: BallType
    
    var body: some View {
        ZStack {
            switch ballType {
            case .classic:
                ClassicBallView(position: ball.position)
            case .shooter:
                ShooterBallView(position: ball.position)
            case .power:
                PowerBallView(position: ball.position)
            case .golden:
                GoldenBallView(position: ball.position)
            }
        }
    }
}

struct ClassicBallView: View {
    let position: CGPoint
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [.white, .orange, .red]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 20
                    )
                )
                .frame(width: 40, height: 40)
                .position(position)
                .shadow(color: .orange, radius: 5, x: 0, y: 2)
            
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 30, height: 3)
                    .position(position)
                    .rotationEffect(.degrees(Double(i) * 60))
            }
        }
    }
}

struct ShooterBallView: View {
    let position: CGPoint
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [.white, .red, .black]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 20
                    )
                )
                .frame(width: 35, height: 35)
                .position(position)
                .shadow(color: .red, radius: 8, x: 0, y: 2)
            
            // Basketball pattern
            ForEach(0..<2, id: \.self) { i in
                Capsule()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 25, height: 4)
                    .position(position)
                    .rotationEffect(.degrees(Double(i) * 90))
            }
        }
    }
}

struct PowerBallView: View {
    let position: CGPoint
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [.white, .purple, .black]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 20
                    )
                )
                .frame(width: 45, height: 45)
                .position(position)
                .shadow(color: .purple, radius: 10, x: 0, y: 3)
            
            // Football pattern
            Capsule()
                .fill(Color.white.opacity(0.8))
                .frame(width: 35, height: 8)
                .position(position)
            
            Capsule()
                .fill(Color.white.opacity(0.8))
                .frame(width: 35, height: 8)
                .position(position)
                .rotationEffect(.degrees(90))
        }
    }
}

struct GoldenBallView: View {
    let position: CGPoint
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [.yellow, .orange, .red]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 20
                    )
                )
                .frame(width: 38, height: 38)
                .position(position)
                .shadow(color: .yellow, radius: 15, x: 0, y: 0)
            
            // Sparkle effect
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                    .position(
                        x: position.x + cos(Double(i) * .pi / 2) * 25,
                        y: position.y + sin(Double(i) * .pi / 2) * 25
                    )
                    .blur(radius: 2)
            }
        }
    }
}

// MARK: - Level Complete Popup
struct LevelCompletePopup: View {
    @EnvironmentObject var gameManager: GameManager
    
    var body: some View {
        Color.black.opacity(0.8)
            .ignoresSafeArea()
        
        VStack(spacing: 25) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 80))
                .foregroundColor(.yellow)
                .shadow(color: .yellow, radius: 10)
            
            Text("Level Complete!")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundColor(.white)
            
            Text("Congratulations!")
                .font(.title2)
                .foregroundColor(.yellow)
            
            VStack(spacing: 15) {
                InfoRow(label: "Level", value: "\(gameManager.currentLevel.number)", color: .blue)
                InfoRow(label: "Your Score", value: "\(gameManager.score)", color: .green)
                InfoRow(label: "Target Score", value: "\(gameManager.currentLevel.targetScore)", color: .orange)
                
                if gameManager.score >= gameManager.currentLevel.targetScore {
                    Text("🎉 Target Achieved! 🎉")
                        .font(.headline)
                        .foregroundColor(.green)
                        .padding(.top, 10)
                }
            }
            .padding()
            .background(Color.black.opacity(0.6))
            .cornerRadius(15)
            
            HStack(spacing: 20) {
                if gameManager.currentLevel.number < Level.levels.count {
                    Button("Next Level") {
                        gameManager.showLevelComplete = false
                        let nextLevel = Level.levels[gameManager.currentLevel.number]
                        gameManager.startGame(level: nextLevel)
                    }
                    .gameButton(backgroundColor: .green)
                }
                
                Button("Menu") {
                    gameManager.showLevelComplete = false
                    gameManager.currentScreen = .mainMenu
                }
                .gameButton(backgroundColor: .blue)
            }
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.purple.opacity(0.9), Color.blue.opacity(0.9)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.yellow, lineWidth: 4)
                )
                .shadow(color: .black.opacity(0.3), radius: 20)
        )
        .padding(.horizontal, 25)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            Text(value)
                .font(.title3)
                .fontWeight(.black)
                .foregroundColor(color)
        }
    }
}


// MARK: - Enhanced Hit Effect View
struct HitEffectView: View {
    let position: CGPoint
    var color: Color = .white
    
    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .stroke(color, lineWidth: 3)
                    .frame(width: 25 + CGFloat(i) * 20, height: 25 + CGFloat(i) * 20)
                    .position(position)
                    .opacity(1 - Double(i) * 0.25)
            }
        }
        .animation(.easeOut(duration: 0.4), value: position)
    }
}

// MARK: - Net View
struct NetView: View {
    var body: some View {
        ZStack {
            // Net posts (thin and only visual)
            Rectangle()
                .fill(Color.gray.opacity(0.7))
                .frame(width: 6, height: 180)
                .offset(x: -UIScreen.main.bounds.width / 2 + 3, y: -40)
            
            Rectangle()
                .fill(Color.gray.opacity(0.7))
                .frame(width: 6, height: 180)
                .offset(x: UIScreen.main.bounds.width / 2 - 3, y: -40)
            
            // Net (transparent - just visual guide)
            ForEach(0..<8, id: \.self) { i in
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: UIScreen.main.bounds.width - 20, height: 2)
                    .offset(y: CGFloat(i) * 25 - 140)
            }
        }
    }
}


// MARK: - Enhanced Wobble Character with Device Compatibility
struct WobbleCharacter: View {
    @ObservedObject var gameEngine: GameEngine
    let screenHeight: CGFloat
    
    var body: some View {
        let isSmallDevice = screenHeight < 700
        
        ZStack {
            // Body - Adjusted size for different screens
            Ellipse()
                .fill(Color.blue)
                .frame(width: isSmallDevice ? 60 : 80, height: isSmallDevice ? 90 : 120)
                .position(x: 200, y: isSmallDevice ? 400 : 450)
            
            // Left Hand with left hand icon
            ZStack {
                Image(systemName: gameEngine.character.isLeftHandReady ? "hand.point.left.fill" : "hand.point.left")
                    .font(.system(size: isSmallDevice ? 24 : 30))
                    .foregroundColor(gameEngine.character.isLeftHandReady ? .orange : .gray)
                    .frame(width: isSmallDevice ? 50 : 60, height: isSmallDevice ? 50 : 60)
                    .background(
                        Circle()
                            .fill(gameEngine.character.isLeftHandReady ? Color.white.opacity(0.3) : Color.gray.opacity(0.3))
                            .frame(width: isSmallDevice ? 50 : 60, height: isSmallDevice ? 50 : 60)
                    )
                    .position(gameEngine.character.leftHandPosition)
                    .offset(x: gameEngine.character.leftHandWobble)
                    .shadow(color: gameEngine.character.isLeftHandReady ? .orange : .gray, radius: 5)
                
                if !gameEngine.character.isLeftHandReady {
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: isSmallDevice ? 45 : 55, height: isSmallDevice ? 45 : 55)
                        .position(gameEngine.character.leftHandPosition)
                }
            }
            
            // Right Hand with right hand icon
            ZStack {
                Image(systemName: gameEngine.character.isRightHandReady ? "hand.point.right.fill" : "hand.point.right")
                    .font(.system(size: isSmallDevice ? 24 : 30))
                    .foregroundColor(gameEngine.character.isRightHandReady ? .orange : .gray)
                    .frame(width: isSmallDevice ? 50 : 60, height: isSmallDevice ? 50 : 60)
                    .background(
                        Circle()
                            .fill(gameEngine.character.isRightHandReady ? Color.white.opacity(0.3) : Color.gray.opacity(0.3))
                            .frame(width: isSmallDevice ? 50 : 60, height: isSmallDevice ? 50 : 60)
                    )
                    .position(gameEngine.character.rightHandPosition)
                    .offset(x: gameEngine.character.rightHandWobble)
                    .shadow(color: gameEngine.character.isRightHandReady ? .orange : .gray, radius: 5)
                
                if !gameEngine.character.isRightHandReady {
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: isSmallDevice ? 45 : 55, height: isSmallDevice ? 45 : 55)
                        .position(gameEngine.character.rightHandPosition)
                }
            }
            
            // Head with larger hit area
            ZStack {
                Circle()
                    .fill(gameEngine.character.isHeadReady ? Color.yellow : Color.gray)
                    .frame(width: isSmallDevice ? 55 : 70, height: isSmallDevice ? 55 : 70)
                    .position(gameEngine.character.headPosition)
                    .rotationEffect(.degrees(gameEngine.character.headWobble))
                    .shadow(color: gameEngine.character.isHeadReady ? .yellow : .gray, radius: 5)
                
                if !gameEngine.character.isHeadReady {
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: isSmallDevice ? 60 : 75, height: isSmallDevice ? 60 : 75)
                        .position(gameEngine.character.headPosition)
                }
                
                // Face (only when ready)
                if gameEngine.character.isHeadReady {
                    Group {
                        // Eyes
                        Circle()
                            .fill(Color.black)
                            .frame(width: isSmallDevice ? 8 : 10, height: isSmallDevice ? 8 : 10)
                            .position(x: gameEngine.character.headPosition.x - (isSmallDevice ? 12 : 15),
                                     y: gameEngine.character.headPosition.y - (isSmallDevice ? 6 : 8))
                        
                        Circle()
                            .fill(Color.black)
                            .frame(width: isSmallDevice ? 8 : 10, height: isSmallDevice ? 8 : 10)
                            .position(x: gameEngine.character.headPosition.x + (isSmallDevice ? 12 : 15),
                                     y: gameEngine.character.headPosition.y - (isSmallDevice ? 6 : 8))
                        
                        // Mouth
                        Capsule()
                            .fill(Color.black)
                            .frame(width: isSmallDevice ? 20 : 25, height: isSmallDevice ? 4 : 6)
                            .position(x: gameEngine.character.headPosition.x,
                                     y: gameEngine.character.headPosition.y + (isSmallDevice ? 12 : 15))
                    }
                }
            }
        }
    }
}

// MARK: - Updated Control Guides View
struct ControlGuidesView: View {
    var body: some View {
        GeometryReader { geometry in
            let isSmallDevice = geometry.size.height < 700
            
            VStack {
                Spacer()
                
                HStack {
                    VStack {
                        Text("← DRAG LEFT HAND")
                            .font(.system(size: isSmallDevice ? 10 : 12, weight: .bold))
                            .foregroundColor(.orange)
                            .padding(6)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(6)
                        
                        Circle()
                            .stroke(Color.orange, lineWidth: 2)
                            .frame(width: isSmallDevice ? 50 : 70, height: isSmallDevice ? 50 : 70)
                    }
                    
                    Spacer()
                    
                    VStack {
                        Text("TAP HEAD")
                            .font(.system(size: isSmallDevice ? 10 : 12, weight: .bold))
                            .foregroundColor(.yellow)
                            .padding(6)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(6)
                        
                        Circle()
                            .stroke(Color.yellow, lineWidth: 2)
                            .frame(width: isSmallDevice ? 45 : 60, height: isSmallDevice ? 45 : 60)
                    }
                    
                    Spacer()
                    
                    VStack {
                        Text("DRAG RIGHT HAND →")
                            .font(.system(size: isSmallDevice ? 10 : 12, weight: .bold))
                            .foregroundColor(.orange)
                            .padding(6)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(6)
                        
                        Circle()
                            .stroke(Color.orange, lineWidth: 2)
                            .frame(width: isSmallDevice ? 50 : 70, height: isSmallDevice ? 50 : 70)
                    }
                }
                .padding(.horizontal, isSmallDevice ? 20 : 30)
                .padding(.bottom, isSmallDevice ? 120 : 150)
            }
        }
    }
}


// MARK: - Updated Controls View with Device Compatibility
struct ControlsView: View {
    @ObservedObject var gameEngine: GameEngine
    let isSmallDevice: Bool
    @Binding var showControlHints: Bool
    
    var body: some View {
        VStack(spacing: isSmallDevice ? 8 : 10) {
            HStack {
                Text("Drag hands to position them, tap for quick hits!")
                    .font(.system(size: isSmallDevice ? 12 : 14))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    showControlHints.toggle()
                }) {
                    Image(systemName: showControlHints ? "eye.fill" : "eye.slash.fill")
                        .font(.system(size: isSmallDevice ? 14 : 16))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                }
            }
            .padding(.bottom, 5)
            
            HStack(spacing: isSmallDevice ? 20 : 30) {
                // Left Hand Button
                ControlButton(
                    icon: "hand.point.left.fill",
                    color: .orange,
                    isReady: gameEngine.character.isLeftHandReady,
                    isSmallDevice: isSmallDevice,
                    action: {
                        gameEngine.animateLeftHandHit()
                    }
                )
                
                // Head Button
                ControlButton(
                    icon: "brain.head.profile",
                    color: .yellow,
                    isReady: gameEngine.character.isHeadReady,
                    isSmallDevice: isSmallDevice,
                    action: {
                        gameEngine.animateHeadHit()
                    }
                )
                
                // Right Hand Button
                ControlButton(
                    icon: "hand.point.right.fill",
                    color: .orange,
                    isReady: gameEngine.character.isRightHandReady,
                    isSmallDevice: isSmallDevice,
                    action: {
                        gameEngine.animateRightHandHit()
                    }
                )
            }
            
            // Reset Hands Button
            Button("Reset Hands Position") {
                gameEngine.resetHandPositions()
            }
            .font(.system(size: isSmallDevice ? 12 : 14, weight: .bold))
            .foregroundColor(.white)
            .padding(isSmallDevice ? 8 : 10)
            .background(Color.purple.opacity(0.8))
            .cornerRadius(8)
            .padding(.top, isSmallDevice ? 2 : 5)
        }
        .padding(.horizontal, isSmallDevice ? 15 : 20)
    }
}

// MARK: - Updated Control Button with Device Compatibility
struct ControlButton: View {
    let icon: String
    let color: Color
    let isReady: Bool
    let isSmallDevice: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            guard isReady else { return }
            isPressed = true
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
        }) {
            ZStack {
                Image(systemName: icon)
                    .font(.system(size: isSmallDevice ? 20 : 30))
                    .foregroundColor(.white)
                    .frame(width: isSmallDevice ? 60 : 80, height: isSmallDevice ? 60 : 80)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: isReady ?
                                [color, color.opacity(0.7)] :
                                [Color.gray, Color.gray.opacity(0.5)]
                            ),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(isSmallDevice ? 15 : 20)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                    .shadow(color: isReady ? color : .gray, radius: isPressed ? 3 : 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: isSmallDevice ? 15 : 20)
                            .stroke(Color.white, lineWidth: 2)
                    )
                
                if !isReady {
                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: isSmallDevice ? 50 : 70, height: isSmallDevice ? 50 : 70)
                        .rotationEffect(.degrees(-90))
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isReady)
    }
}

// MARK: - Enhanced Opponent View
struct OpponentView: View {
    let opponent: GameEngine.Opponent
    
    var body: some View {
        ZStack {
            // Opponent body with difficulty-based color
            let difficultyColor = opponent.difficulty > 2.0 ? Color.red :
                                opponent.difficulty > 1.5 ? Color.orange :
                                opponent.difficulty > 1.2 ? Color.yellow : Color.pink
            
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [difficultyColor, difficultyColor.opacity(0.7)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 60, height: 60)
                .position(opponent.position)
                .shadow(color: difficultyColor, radius: 8)
            
            // Arms
            Capsule()
                .fill(difficultyColor)
                .frame(width: 80, height: 20)
                .position(x: opponent.position.x, y: opponent.position.y + 15)
                .rotationEffect(.degrees(10))
            
        }
    }
}


// MARK: - Modern Compact Score Card
struct ScoreCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.3), radius: 5, x: 0, y: 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
    }
}



// MARK: - Updated Game Over View with Fixed Navigation
struct GameOverView: View {
    @EnvironmentObject var gameManager: GameManager
    @State private var isNavigating = false
    
    var body: some View {
        ZStack {
            // Enhanced background with gradient overlay
            GameBackground()
                .overlay(
                    LinearGradient(
                        colors: [Color.black.opacity(0.3), Color.black.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            VStack(spacing: 0) {
                // Header Section
                VStack(spacing: 8) {
                    Text("Game Over!")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                    
                    Text("Level \(gameManager.currentLevel.number) - \(gameManager.currentLevel.name)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.yellow)
                        .opacity(0.9)
                }
                .padding(.top, 60)
                .padding(.bottom, 30)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Results Cards - Compact and Modern
                        VStack(spacing: 16) {
                            HStack(spacing: 12) {
                                ScoreCard(
                                    title: "Your Score",
                                    value: "\(gameManager.score)",
                                    color: .blue,
                                    icon: "star.fill"
                                )
                                
                                ScoreCard(
                                    title: "Target",
                                    value: "\(gameManager.currentLevel.targetScore)",
                                    color: .orange,
                                    icon: "target"
                                )
                            }
                            
                            ScoreCard(
                                title: "High Score",
                                value: "\(gameManager.highScore)",
                                color: .yellow,
                                icon: "crown.fill"
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        // Achievement Badge
                        if gameManager.score >= gameManager.currentLevel.targetScore {
                            AchievementBadge()
                        } else {
                            EncouragementMessage()
                        }
                        
                        // Action Buttons with navigation prevention
                        VStack(spacing: 12) {
                            ActionButton(
                                title: "Play Again",
                                icon: "arrow.clockwise",
                                color: .green,
                                isDisabled: isNavigating
                            ) {
                                guard !isNavigating else { return }
                                isNavigating = true
                                gameManager.startGame(level: gameManager.currentLevel)
                            }
                            
                            ActionButton(
                                title: "Level Select",
                                icon: "square.grid.2x2",
                                color: .blue,
                                isDisabled: isNavigating
                            ) {
                                guard !isNavigating else { return }
                                isNavigating = true
                                gameManager.navigateToScreen(.levelSelect)
                            }
                            
                            ActionButton(
                                title: "Main Menu",
                                icon: "house.fill",
                                color: .purple,
                                isDisabled: isNavigating
                            ) {
                                guard !isNavigating else { return }
                                isNavigating = true
                                gameManager.navigateToScreen(.mainMenu)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            // Reset navigating state when view appears
            isNavigating = false
        }
    }
}

// MARK: - Updated Action Button with Disabled State
struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    var isDisabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isDisabled {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: isDisabled ?
                        [Color.gray, Color.gray.opacity(0.8)] :
                        [color, color.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: isDisabled ? .gray.opacity(0.4) : color.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isDisabled)
    }
}

// MARK: - Achievement Badge
struct AchievementBadge: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundColor(.green)
                .shadow(color: .green.opacity(0.5), radius: 5)
            
            Text("Level Target Achieved!")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(LinearGradient(
                    colors: [Color.green.opacity(0.2), Color.green.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .overlay(
                    Capsule()
                        .stroke(Color.green.opacity(0.4), lineWidth: 1)
                )
        )
    }
}

// MARK: - Encouragement Message
struct EncouragementMessage: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 14))
                .foregroundColor(.orange)
            
            Text("Keep practicing! You'll get it next time!")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    Capsule()
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Enhanced Game Background
struct GameBackground: View {
    @State private var cloudOffset: CGFloat = 0
    @State private var gradientRotation = 0.0
    
    var body: some View {
        ZStack {
            // Animated Sky Gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.8),
                    Color.purple.opacity(0.6),
                    Color.orange.opacity(0.4)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .rotationEffect(.degrees(gradientRotation))
            
            // Stars for night effect
            ForEach(0..<20, id: \.self) { index in
                Circle()
                    .fill(Color.white)
                    .frame(width: CGFloat.random(in: 1...3), height: CGFloat.random(in: 1...3))
                    .position(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height/2)
                    )
                    .opacity(Double.random(in: 0.3...0.8))
            }
            
            // Animated Clouds
            ForEach(0..<4, id: \.self) { index in
                CloudView()
                    .offset(
                        x: cloudOffset + CGFloat(index) * 150,
                        y: CGFloat(index) * 60 + 80
                    )
                    .opacity(0.6 + Double(index) * 0.1)
            }
            
        
            
            // Court with improved design
            VStack {
                Spacer()
                
                ZStack {
                    // Court surface
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.green.opacity(0.9),
                                    Color.green.opacity(0.6),
                                    Color.green.opacity(0.4)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: UIScreen.main.bounds.height / 2)
                    
                    // Court lines
                    Rectangle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        .frame(height: UIScreen.main.bounds.height / 2)
                    
                    // Center line
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 4, height: UIScreen.main.bounds.height / 2)
                    
                    // Court markings
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            .frame(width: CGFloat(i) * 40 + 20, height: CGFloat(i) * 40 + 20)
                    }
                }
            }
        }

    }
}

// MARK: - Enhanced Cloud View
struct CloudView: View {
    @State private var opacity = Double.random(in: 0.4...0.8)
    
    var body: some View {
        ZStack {
            // Main cloud body
            Circle()
                .fill(Color.white.opacity(opacity))
                .frame(width: 60, height: 60)
                .offset(x: -25, y: 0)
            
            Circle()
                .fill(Color.white.opacity(opacity))
                .frame(width: 80, height: 80)
                .offset(x: 0, y: -5)
            
            Circle()
                .fill(Color.white.opacity(opacity))
                .frame(width: 70, height: 70)
                .offset(x: 25, y: -10)
            
            Circle()
                .fill(Color.white.opacity(opacity))
                .frame(width: 50, height: 50)
                .offset(x: 15, y: 15)
            
            Circle()
                .fill(Color.white.opacity(opacity))
                .frame(width: 45, height: 45)
                .offset(x: -15, y: 10)
        }
        .frame(width: 120, height: 60)
        .onAppear {
            // Random opacity animation for clouds
            withAnimation(Animation.easeInOut(duration: Double.random(in: 2...4)).repeatForever()) {
                opacity = Double.random(in: 0.3...0.7)
            }
        }
    }
}

// MARK: - Updated Tutorial Popup
struct TutorialPopupView: View {
    @Binding var isShowing: Bool
    @Binding var gameStarted: Bool
    @Binding var showControlHints: Bool
    @ObservedObject var gameEngine: GameEngine
    let screenWidth: CGFloat
    let isSmallDevice: Bool
    
    var body: some View {
        Color.black.opacity(0.8)
            .ignoresSafeArea()
        
        VStack(spacing: isSmallDevice ? 15 : 25) {
            // Header
            VStack(spacing: isSmallDevice ? 8 : 12) {
                Image(systemName: "volleyball.circle.fill")
                    .font(.system(size: isSmallDevice ? 40 : 50))
                    .foregroundColor(.yellow)
                
                Text("How Game Work?")
                    .font(.system(size: isSmallDevice ? 24 : 32, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Body Part Volleyball")
                    .font(.system(size: isSmallDevice ? 16 : 20, weight: .medium))
                    .foregroundColor(.yellow)
            }
            
            // Instructions
            VStack(alignment: .leading, spacing: isSmallDevice ? 10 : 15) {
                InstructionRow(
                    icon: "hand.point.left.fill",
                    text: "Drag LEFT hand to position it",
                    color: .orange,
                    isSmallDevice: isSmallDevice
                )
                
                InstructionRow(
                    icon: "hand.point.right.fill",
                    text: "Drag RIGHT hand to position it",
                    color: .orange,
                    isSmallDevice: isSmallDevice
                )
                
                InstructionRow(
                    icon: "brain.head.profile",
                    text: "Tap HEAD for powerful hits",
                    color: .yellow,
                    isSmallDevice: isSmallDevice
                )
                
                InstructionRow(
                    icon: "target",
                    text: "Hit ball to opponent's side to score!",
                    color: .green,
                    isSmallDevice: isSmallDevice
                )
                
                InstructionRow(
                    icon: "clock",
                    text: "\(gameEngine.gameManager?.currentLevel.time ?? 60) seconds to score!",
                    color: .blue,
                    isSmallDevice: isSmallDevice
                )
                
                InstructionRow(
                    icon: "star.fill",
                    text: "Target: \(gameEngine.gameManager?.currentLevel.targetScore ?? 0) points",
                    color: .purple,
                    isSmallDevice: isSmallDevice
                )
            }
            .padding(.horizontal)
            
            // Start Button
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isShowing = false
                    gameStarted = true
                    showControlHints = true
                    // Start the game engine only when user clicks start
                    gameEngine.startGame()
                }
            }) {
                HStack {
                    Image(systemName: "play.circle.fill")
                    Text("Start Game!")
                }
                .font(.system(size: isSmallDevice ? 18 : 22, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, isSmallDevice ? 30 : 40)
                .padding(.vertical, isSmallDevice ? 12 : 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.green, .blue]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(isSmallDevice ? 20 : 25)
                .shadow(color: .green, radius: 10)
            }
            .padding(.top, isSmallDevice ? 5 : 10)
            
            // Quick Tip
            Text("Tip: You can also tap the buttons for quick hits!")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(isSmallDevice ? 20 : 30)
        .background(
            RoundedRectangle(cornerRadius: isSmallDevice ? 20 : 25)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.purple.opacity(0.9), Color.blue.opacity(0.9)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: isSmallDevice ? 20 : 25)
                        .stroke(Color.white, lineWidth: 3)
                )
                .shadow(color: .black.opacity(0.3), radius: 20)
        )
        .padding(.horizontal, isSmallDevice ? 15 : 25)
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Instruction Row
struct InstructionRow: View {
    let icon: String
    let text: String
    let color: Color
    let isSmallDevice: Bool
    
    var body: some View {
        HStack(spacing: isSmallDevice ? 12 : 15) {
            Image(systemName: icon)
                .font(.system(size: isSmallDevice ? 16 : 20))
                .foregroundColor(color)
                .frame(width: isSmallDevice ? 20 : 25)
            
            Text(text)
                .font(.system(size: isSmallDevice ? 14 : 16, weight: .medium))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}
// MARK: - Helper extension for game buttons
extension View {
    func gameButton(backgroundColor: Color) -> some View {
        self
            .font(.title3)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 30)
            .padding(.vertical, 15)
            .background(backgroundColor)
            .cornerRadius(20)
            .shadow(color: backgroundColor, radius: 10)
    }
}


