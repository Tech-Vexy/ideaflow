# IdeaFlow 🌊

**IdeaFlow** is a local-first, voice-enabled innovation incubator powered by **IBM watsonx** and **Firebase**.
It allows users to capture ideas via voice, iteratively brainstorm with AI, and track the evolution of their thoughts.

## 🚀 Features

*   **🎙️ Voice Capture**: Real-time speech-to-text recording.
*   **🧠 Iterative Brainstorming**: A "GitHub for Ideas" timeline view that tracks the evolution of your concepts.
*   **🤖 IBM watsonx AI**: Powered by **Granite 3.3** for high-quality technical insights and summarization.
*   **🔐 Hybrid Security**: **Firebase Authentication** (Email/Google) ensures secure access, while **Drift** (SQLite) keeps your data local-first.
*   **🎨 Premium UI**: "Deep Violet" themed dynamic interface built with Flutter Riverpod.

## 🛠️ Setup & Configuration

### 1. Prerequisites
*   Flutter SDK (Legacy or Stable)
*   Firebase Account
*   IBM Cloud Account (for Watson)

### 2. Firebase Configuration (Crucial!)
This app uses **Firebase Auth** for user identity.
1.  Go to the [Firebase Console](https://console.firebase.google.com/).
2.  Create a project and enable **Authentication** (Email/Password provider).
3.  Add an Android App to the project.
4.  **Download `google-services.json`** and place it in:
    ```
    android/app/google-services.json
    ```
5.  *(Optional)* Run `flutterfire configure` to generate `lib/firebase_options.dart` for iOS/Web support.

### 3. IBM Watson Keys
Open `lib/services/watson_service.dart` and update:
*   `_apiKey`: Your IBM Cloud IAM API Key.
*   `_projectId`: Your Watson Machine Learning Project ID.
*   `_wmlUrl`: Your region's endpoint (default is Dallas `us-south`).

### 4. Running the App
```bash
flutter pub get
flutter run
```

## 📂 Project Structure

*   `lib/database/`: Drift SQLite database schema (Ideas & Sessions).
*   `lib/services/`:
    *   `auth_service.dart`: Firebase Auth logic.
    *   `watson_service.dart`: IBM Granite integration.
    *   `voice_service.dart`: On-device speech-to-text.
*   `lib/ui/`:
    *   `widgets/`: Reusable components (RecordingSheet).
    *   `home_screen.dart`: Main dashboard.
    *   `idea_timeline_screen.dart`: The core brainstorming UI.

## 🤝 Contributing
Built for the **IBM Dev Day Hackathon 2026**.
