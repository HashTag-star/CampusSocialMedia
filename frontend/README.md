# Campus Social Media - Frontend

This is the Flutter frontend for the Campus Social Media application.

## Setup

1.  Navigate to this directory:
    ```bash
    cd frontend
    ```
2.  Install dependencies:
    ```bash
    flutter pub get
    ```
3.  **Important**: Since this project was generated manually, you might need to generate the native Android/iOS folders:
    ```bash
    flutter create .
    ```
    *Note: If prompted, select "keep" to preserve existing files (like `pubspec.yaml` and `lib/`).*

4.  Run the app:
    ```bash
    flutter run
    ```

## Architecture

We follow a **Clean Architecture** approach with **Riverpod**:

-   `lib/core`: Global utilities, constants, themes.
-   `lib/features`: Feature-based modules (Auth, Feed, Spaces).
    -   `data`: Repositories & DTOs.
    -   `domain`: Entities & Use Cases.
    -   `presentation`: Widgets & Providers.

## Key Features
-   **Auth**: Login/Register with University Email.
-   **Feed**: Infinite scroll of posts.
-   **Spaces**: Real-time audio rooms.
