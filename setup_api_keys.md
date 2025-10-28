# API Keys Setup Guide

## 🔑 How to Configure Your API Keys

### Method 1: Using dart-define (Recommended)
Run your app with the API key as a build argument:

```bash
# For Gemini API (Google AI)
flutter run --dart-define=GEMINI_API_KEY=your_actual_gemini_api_key_here

# For OpenAI API (alternative)
flutter run --dart-define=OPENAI_API_KEY=sk-your_openai_key_here

# For both
flutter run --dart-define=GEMINI_API_KEY=your_gemini_key --dart-define=OPENAI_API_KEY=your_openai_key
```

### Method 2: Direct Code Replacement
Edit `lib/core/config/ai_config.dart` and replace:
```dart
defaultValue: 'YOUR_GEMINI_API_KEY_HERE'
```
with:
```dart
defaultValue: 'your_actual_gemini_api_key_here'
```

## 🔧 Getting API Keys

### Gemini API Key (Google AI)
1. Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Click "Create API Key"
3. Copy the generated key
4. It should look like: `AIzaSyA...` (39 characters)

### OpenAI API Key (Alternative)
1. Go to [OpenAI Platform](https://platform.openai.com/api-keys)
2. Create new secret key
3. Copy the generated key
4. It should look like: `sk-...`

## ✅ Testing Your Setup
The app will show an error message if the API key is missing or invalid. Look for:
- Chat features working properly
- No "API key missing" errors in logs

## 🚀 Quick Start
```bash
# Replace with your actual key
flutter run --dart-define=GEMINI_API_KEY=AIzaSyA...your_key_here
```
