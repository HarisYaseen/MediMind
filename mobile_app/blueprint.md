# Blueprint: MediMind App

## Overview

This document outlines the plan for creating a "MediMind" medicine reminder application based on the provided UI mockups. The app will help users schedule and manage their medication reminders through a clean, step-by-step interface.

## Features

- **Home Screen:** Displays a list of scheduled medicines or a prompt to add the first one.
- **Add Medicine Flow:** A multi-step wizard to add a new medicine reminder:
  - **Step 1 (Details):** Enter medicine name, dosage, and optional notes.
  - **Step 2 (Schedule):** Define the frequency (e.g., every day, specific days) and set reminder times.
  - **Step 3 (Alert):** Choose an alert sound for the reminder.
- **Settings:** A screen to manage app settings, including an option to clear all data.
- **Navigation:** A bottom navigation bar for easy access to Home, Add Medicine, and Settings.
- **Theming:** A modern, clean design with light/dark mode support and custom typography.

## Design

- **Theme:** The app will use Material Design 3. The color scheme will be based on the blues, teals, and light greys from the mockups.
- **Typography:** `google_fonts` will be used to match the clean aesthetic.
- **Layout:** The layout will be component-based, with reusable widgets for buttons, form fields, and navigation elements.
- **Icons:** Standard Material Design icons will be used for navigation and actions.

## Architecture

- **Routing:** `go_router` will be used for declarative navigation to handle the different screens and the multi-step "Add Medicine" flow.
- **State Management:** The `provider` package will manage the app's state, including the list of medicines, theme settings, and the state of the new medicine being created.
- **Project Structure:** The project will be organized by feature, with separate directories for screens, models, providers, and widgets.

## Plan

1.  **Add Dependencies:** Add `go_router` to the `pubspec.yaml` file for navigation.
2.  **Update Project Structure:** Create new directories for `models`, `providers`, `screens`, and `widgets` to organize the code.
3.  **Implement Core Navigation:** Set up the main `MaterialApp.router` with `go_router` and the bottom navigation bar.
4.  **Build Screens:** Create the individual screens: Home, Settings, and the three-step "Add Medicine" flow.
5.  **Create Models and Providers:** Define the `Medicine` model and create a `MedicineProvider` to manage the application's data.
6.  **Implement Logic:** Wire up the UI to the providers to handle adding, saving, and displaying medicines.
7.  **Refine UI & Theme:** Apply the final colors, fonts, and styles to match the mockups.
