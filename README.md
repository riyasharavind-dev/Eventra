Sure bro. Add this as the **root `Eventra/README.md`**. It is written as a proper GitHub project README, based on the Eventra architecture we've been building.

````markdown
# Eventra

### Eventra — Event Management & Service Marketplace Platform

Eventra is a modern event management platform designed to connect **customers, event service vendors, and administrators** through a single ecosystem.

The platform helps customers discover and book event-related services such as decoration, photography, catering, venues, planning, and other event services.

Eventra consists of three main applications:

- 📱 Customer App
- 🏪 Vendor App
- 🛠️ Admin Panel

All applications share a common backend powered by **Supabase**.

---

## 🚀 Project Vision

Eventra aims to simplify the process of planning and managing events by bringing customers and verified service providers together in one platform.

### Customer

Customers can:

- Discover event services
- Explore vendors
- View services and packages
- Compare available options
- Select event date and requirements
- Select event location
- Create bookings
- Track bookings
- Receive notifications
- Manage their profile

### Vendor

Vendors can:

- Create and manage their business profile
- Add services
- Create packages
- Manage plans
- Manage collaborations
- Receive customer bookings
- Accept or reject bookings
- Manage their business information
- Receive notifications

### Admin

Administrators can:

- Manage customers
- Manage vendors
- Manage categories
- Manage event types
- Manage services
- Manage packages
- Manage plans
- Manage collaborations
- Manage bookings
- Manage promotional banners
- Manage platform settings

---

# 🏗️ Architecture

Eventra follows a multi-application architecture.

```text
                         EVENTRA
                            │
             ┌──────────────┼──────────────┐
             │              │              │
             ▼              ▼              ▼
        CUSTOMER APP    VENDOR APP     ADMIN PANEL
             │              │              │
             └──────────────┼──────────────┘
                            │
                            ▼
                       SUPABASE
                            │
              ┌─────────────┼─────────────┐
              │             │             │
              ▼             ▼             ▼
        PostgreSQL       Storage      Edge Functions
              │
              ▼
        Authentication
              │
              ▼
       Notification System
````

---

# 📁 Project Structure

```text
Eventra/
│
├── admin/
│   ├── lib/
│   ├── android/
│   ├── assets/
│   ├── pubspec.yaml
│   └── README.md
│
├── customer/
│   ├── lib/
│   ├── android/
│   ├── assets/
│   ├── pubspec.yaml
│   └── README.md
│
├── vendor/
│   ├── lib/
│   ├── android/
│   ├── assets/
│   ├── pubspec.yaml
│   └── README.md
│
├── supabase/
│   ├── migrations/
│   ├── functions/
│   └── config.toml
│
├── package.json
├── package-lock.json
├── .gitignore
└── README.md
```

---

# 📱 Applications

## Customer App

The Customer App is built with Flutter.

Main modules include:

* Authentication
* Home
* Discover
* Event Services
* Service Details
* Booking
* Location Selection
* Bookings
* Profile
* Notifications

---

## 🏪 Vendor App

The Vendor App is built with Flutter.

Main modules include:

* Vendor Authentication
* Vendor Profile
* Dashboard
* Services
* Packages
* Plans
* Collaborations
* Booking Management
* Customer Requests
* Notifications

---

## 🛠️ Admin Panel

The Admin Panel is built with Flutter.

Main modules include:

* Dashboard
* Categories
* Event Types
* Services
* Packages
* Plans
* Collaborations
* Vendors
* Customers
* Bookings
* Banners
* Settings

---

# ☁️ Backend

Eventra uses **Supabase** as its backend platform.

Backend components include:

* PostgreSQL Database
* Supabase Authentication
* Supabase Storage
* Row Level Security
* Edge Functions
* Database Triggers

---

# 🔐 Authentication

Eventra uses Supabase Authentication.

The identity architecture is:

```text
auth.users
     │
     ▼
public.users
     │
     ├── customers
     │
     ├── vendors
     │
     └── admins
```

`public.users` acts as the application's identity source of truth.

---

# 🗄️ Database

The database is based on PostgreSQL through Supabase.

Major entities include:

```text
users
customers
vendors
categories
event_types
services
packages
plans
collabs
bookings
banners
fcm_tokens
```

The database structure will continue to evolve as Eventra development progresses.

---

# 🔔 Notifications

Eventra uses Firebase Cloud Messaging (FCM) for push notifications.

Notification architecture:

```text
Database Event
      │
      ▼
Supabase Trigger
      │
      ▼
Edge Function
      │
      ▼
Firebase Cloud Messaging
      │
      ├──────────────► Customer
      │
      └──────────────► Vendor
```

Examples:

* New booking → Vendor notification
* Booking accepted → Customer notification
* Booking rejected → Customer notification

---

# 🗺️ Maps & Location

Eventra integrates **Mappls** for location-based features.

Planned and implemented location capabilities include:

* Map display
* Event location selection
* Pin selection
* Latitude / Longitude
* Customer event location
* Vendor business location
* Distance-based services

Future location features may include:

* Current location
* Address search
* Address autocomplete
* Nearby vendors
* Distance calculation
* Service radius

---

# 🎨 UI / UX

Eventra follows a modern mobile-first interface.

Design principles:

* Clean Android-style UI
* Simple navigation
* Card-based layouts
* Red and white primary visual language
* Clear call-to-action buttons
* Responsive layouts
* User-friendly booking flow

---

# 🧰 Technology Stack

### Frontend

* Flutter
* Dart
* Material Design

### Backend

* Supabase
* PostgreSQL
* Supabase Edge Functions
* Supabase Storage
* Supabase Authentication

### Notifications

* Firebase Cloud Messaging
* Firebase Core

### Maps

* Mappls

### Development Tools

* Visual Studio Code
* Android Studio
* Flutter SDK
* Dart SDK
* Git
* GitHub
* Supabase CLI

---

# ⚙️ Requirements

Before running Eventra, install:

* Flutter SDK
* Dart SDK
* Android Studio
* Android SDK
* Git
* Node.js
* npm
* Supabase CLI

---

# 🚀 Getting Started

Clone the repository:

```bash
git clone <YOUR_GITHUB_REPOSITORY_URL>
```

Enter the project:

```bash
cd Eventra
```

---

## Customer App

```bash
cd customer
flutter pub get
flutter run
```

---

## Vendor App

```bash
cd vendor
flutter pub get
flutter run
```

---

## Admin Panel

```bash
cd admin
flutter pub get
flutter run
```

---

# 🔑 Environment & Secrets

Do not commit private credentials or secret keys.

Use environment files or local configuration where required.

Example:

```env
SUPABASE_URL=
SUPABASE_ANON_KEY=
```

Never expose:

```text
SUPABASE_SERVICE_ROLE_KEY
PRIVATE_API_KEYS
PRIVATE_CERTIFICATES
PRIVATE_SIGNING_KEYS
```

---

# 📌 Development Philosophy

Eventra is being developed using an:

> **Architecture-first + Documentation-first approach**

The project is designed as a long-term platform rather than a single prototype.

Major development principles:

* Modular architecture
* Reusable components
* Separate customer/vendor/admin applications
* Centralized backend
* Scalable database design
* Secure authentication
* Maintainable code
* Clear documentation
* Incremental feature development

---

# 🛣️ Roadmap

### Phase 1 — Foundation

* [x] Project structure
* [x] Customer App
* [x] Vendor App
* [x] Admin Panel
* [x] Supabase integration
* [x] Authentication
* [x] Database foundation

### Phase 2 — Marketplace

* [x] Categories
* [x] Event Types
* [x] Services
* [x] Packages
* [x] Plans
* [x] Vendor management
* [x] Customer management

### Phase 3 — Booking

* [x] Booking flow
* [x] Booking management
* [x] Customer booking status
* [x] Vendor booking status
* [x] Push notifications

### Phase 4 — Location

* [x] Map integration foundation
* [x] Event location selection
* [ ] Current location
* [ ] Address search
* [ ] Nearby vendors
* [ ] Distance calculation

### Phase 5 — Platform Growth

* [ ] Vendor verification
* [ ] Reviews & ratings
* [ ] Advanced vendor discovery
* [ ] Payments
* [ ] Analytics
* [ ] Advanced notifications
* [ ] Promotional campaigns
* [ ] Recommendation system

---

# 🔒 Security

Security is an important part of Eventra development.

The project should follow:

* Authentication-based access
* Role-based access
* Database constraints
* Secure API usage
* Storage access control
* Row Level Security where required
* Server-side handling of sensitive operations
* No private credentials in source control

---

# 📄 License

This project is currently under private development.

License and usage terms will be defined separately.

---

# 👨‍💻 Project

**Eventra**

Event Management & Service Marketplace Platform

Built with:

```text
Flutter + Supabase + Firebase + Mappls
```

---

> Eventra — Bringing Events, Customers & Services Together.
