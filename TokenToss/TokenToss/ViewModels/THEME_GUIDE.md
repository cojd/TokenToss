# Token Toss Theme Guide

## 🎨 Design Philosophy

The Token Toss theme is centered around the concept of **tossing coins/tokens** in a playful, engaging way. The design uses warm metallic tones (gold, bronze, silver) combined with strong team distinction colors to create an exciting betting experience.

## 🎯 Core Theme Elements

### Color Palette

#### Primary Colors (Token/Coin Theme)
- **Token Gold**: `#FFD700` - Primary brand color, used for highlights and interactive elements
- **Token Bronze**: `#CC7F33` - Secondary accent, creates depth with gold
- **Token Silver**: `#C0C0C0` - Tertiary accent for variety
- **Token Accent**: `#FFA500` - Orange-gold for CTAs and important actions

#### Team Distinction Colors
- **Home Team Blue**: `#3366CC` - Cool blue for home teams
- **Away Team Red**: `#E64D4D` - Warm red for away teams
- Each team color has light variants for backgrounds (15% opacity)

#### Status Colors
- **Win Green**: `#33CC4D` - Success states, positive outcomes
- **Loss Red**: `#E63333` - Error states, negative outcomes
- **Live Red**: Pulsing red for live games

### Typography
- **Rounded Design**: `.rounded` system font for playful, friendly feel
- **Bold Headers**: Heavy weights for emphasis
- **Token Icon**: Custom "T" icon in circles

## 🎪 Key Components

### 1. Token Icon (`TokenIcon`)
A circular coin-like icon with:
- Gradient fill (gold to bronze)
- Letter "T" in the center
- Soft shadow for depth
- Available in multiple sizes

**Usage:**
```swift
TokenIcon(size: 30, color: .tokenGold)
```

### 2. Coin Toss Animation (`CoinTossIcon`)
An animated flipping coin:
- Continuous 3D rotation effect
- Used in headers and loading states
- Draws attention to key areas

**Usage:**
```swift
CoinTossIcon(size: 40)
```

### 3. Team Badges
Clear visual distinction between home and away teams:
- **Away Team**: Red color scheme, "AWAY" badge
- **Home Team**: Blue color scheme, "HOME" badge
- Colored side indicators (4px width)
- Light background tints for each team section

### 4. Game Cards
Enhanced cards with:
- Gold border gradient
- Team-specific color sections
- VS divider with gold coin icon
- "Tap to Toss Your Tokens" footer
- Elevated shadows with gold tint

### 5. Button Styles

#### Toss Button (`TossButtonStyle`)
Primary action buttons with:
- Gold gradient background
- Dynamic shadow (changes on press)
- Scale animation on tap
- Used for main CTAs

**Usage:**
```swift
Button("Place Bet") { }
    .buttonStyle(TossButtonStyle())
```

## 📱 Screen-by-Screen Theming

### Login Screen
- Animated coin toss logo
- Gold gradient backgrounds
- Custom input fields with gold borders
- "Start Tossing" CTA button

### Games List
- "Toss Your Tokens!" header with coin animation
- Gold-accented status bar
- Team-color-coded game cards
- Strong visual separation between home/away

### Profile
- Gold gradient avatar background
- Token-themed icons throughout
- "Pro Tosser" badge system

### Tab Bar
- Gold accent color
- Token-themed icons:
  - **Toss**: Hexagon grid (coin pattern)
  - **My Tosses**: Clipboard with coins
  - **Tokens**: Coin/cent sign
  - **Leaders**: Trophy
  - **Profile**: Person circle

## 🎨 Modifiers & Extensions

### `.tokenCard()`
Applies consistent card styling:
```swift
VStack { }
    .tokenCard()
```

### `.tokenPulse()`
Adds pulsing animation:
```swift
Circle()
    .tokenPulse()
```

### `LinearGradient.tokenGradient`
Pre-made gold-to-bronze gradient:
```swift
Text("Token Toss")
    .foregroundStyle(LinearGradient.tokenGradient)
```

## 🎯 Design Principles

1. **Playful Yet Professional**: Gold accents add excitement without looking childish
2. **Clear Team Distinction**: Red vs Blue never confuses users
3. **Consistent Token Metaphor**: Coins/tokens appear throughout the experience
4. **Tactile Interactions**: Shadows, gradients, and animations make UI feel physical
5. **Accessibility**: High contrast between team colors and backgrounds

## 🚀 Future Enhancements

- Animated coin flip on successful bet placement
- Particle effects when tokens are "tossed"
- More sophisticated team color themes (could pull from actual NFL team colors)
- Dark mode optimizations with adjusted gold brightness
- Haptic feedback on key interactions

## 📝 Usage Guidelines

### DO:
✅ Use token icons for any currency/point displays
✅ Maintain team color distinction (red/blue) consistently
✅ Add gold accents to interactive elements
✅ Use rounded fonts for friendliness

### DON'T:
❌ Mix team colors (don't use red for home, blue for away)
❌ Overuse animations (coin toss should be special)
❌ Use flat colors where gradients are expected
❌ Ignore the "toss" metaphor in copy and UX

---

**Remember**: Every interaction should feel like you're tossing a valuable token into the game! 🪙✨
