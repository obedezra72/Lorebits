# 📚 Lorebits - NFT Story Unlocks ✨

> *Collect story fragments, unlock epic tales, and dive into decentralized storytelling!*

## 🎭 What is Lorebits?

Lorebits is a revolutionary NFT storytelling platform built on Stacks where creators craft immersive narratives and readers collect story fragments to unlock chapters. Think of it as collecting trading cards, but instead of stats, you're unlocking pieces of incredible stories! 

Each **Lorebit** is a unique NFT that represents a fragment of a larger narrative. Collect the right combination of Lorebits to unlock exclusive story chapters and dive deeper into the lore.

## ✨ Features

- 🎨 **Mint Story NFTs**: Create unique Lorebit tokens with different rarities
- 📖 **Story Creation**: Authors can create multi-chapter stories with unlock requirements  
- 🔓 **Chapter Unlocking**: Use your NFTs + story points to unlock exclusive content
- 💎 **Story Points System**: Earn points by minting, spend them to unlock chapters
- 🔥 **Burn for Rewards**: Sacrifice your NFTs for bonus story points
- 🏆 **Rarity System**: Legendary, Rare, and Common Lorebits with different point values
- 📚 **Reader Rewards**: Daily reading streaks, review system, and achievement badges
- 🏅 **Achievement Badges**: Earn "Reviewer" and "WeeklyStreak" badges for engagement
- 💬 **Chapter Reviews**: Submit reviews and earn bonus story points

## 🚀 Getting Started

### For Readers/Collectors

1. **Mint Lorebits** - Start collecting story fragments
```clarity
(contract-call? .lorebits mint-lorebit 
    u"The Dragon's Eye" 
    u1 
    u1 
    u"rare" 
    u"https://your-metadata-uri.com")
```

2. **Explore Stories** - Browse available stories and their requirements
```clarity
(contract-call? .lorebits get-story u1)
```

3. **Unlock Chapters** - Use your NFTs and story points to unlock content
```clarity
(contract-call? .lorebits unlock-chapter u1 u1)
```

### For Authors/Creators

1. **Create a Story** - Set up your narrative structure
```clarity
(contract-call? .lorebits create-story 
    u"The Chronicles of Stacks" 
    u10 
    u50)
```

2. **Add Chapters** - Upload chapter content with unlock requirements
```clarity
(contract-call? .lorebits add-chapter 
    u1 
    u1 
    u"Chapter 1: The adventure begins..." 
    (list u1 u2) 
    u25)
```

## 🎮 How It Works

### The Collection Game
- Mint Lorebits with different rarities (Common: 25pts, Rare: 50pts, Legendary: 100pts)
- Each Lorebit belongs to a specific story and chapter
- Collect story points automatically when minting

### The Unlock Mechanism  
- Stories are divided into chapters
- Each chapter requires specific Lorebits + story points to unlock
- Once unlocked, you can read the exclusive content forever
- Burn unwanted NFTs for bonus story points

### Rarity & Economics
- **Common** 📄: 25 story points, 50 bonus when burned
- **Rare** 💙: 50 story points, 100 bonus when burned  
- **Legendary** 🌟: 100 story points, 200 bonus when burned

### Reader Rewards System 🎯
- **Daily Reading**: Log your reading activity to build streaks
- **Streak Bonuses**: Every 7-day streak earns 10 bonus points + "WeeklyStreak" badge
- **Chapter Reviews**: Submit thoughtful reviews for 10 story points each
- **Achievement Badges**: Collect "Reviewer" and "WeeklyStreak" badges
- **Base Reading Reward**: 5 story points for each chapter read

## 📋 Contract Functions

### Public Functions
- `mint-lorebit` - Create new story NFTs
- `create-story` - Authors create new stories
- `add-chapter` - Add content to stories
- `unlock-chapter` - Unlock story content
- `transfer` - Transfer NFTs
- `burn-for-points` - Burn NFTs for story points
- `log-reading` - Log reading activity and maintain streaks
- `submit-review` - Submit chapter reviews for rewards

### Read-Only Functions
- `get-token-metadata` - View NFT details
- `get-story` - View story information
- `get-chapter-content` - Read unlocked chapters
- `is-chapter-unlocked` - Check unlock status
- `get-user-points` - Check story point balance
- `get-reader-profile` - View reader stats, streaks, and badges
- `get-chapter-review` - Read specific chapter reviews

## 🛠️ Development

This contract is built for Clarinet and uses the latest Stacks blockchain features:
- Uses `stacks-block-height` for block info
- Implements NFT traits properly
- Includes comprehensive error handling
- Optimized for gas efficiency

## 💡 Use Cases

- **Interactive Fiction**: Create choose-your-own-adventure stories
- **Serialized Novels**: Release chapters progressively  
- **Community Storytelling**: Collaborative narrative building
- **Educational Content**: Gamified learning experiences
- **Brand Storytelling**:# Lorebits

