# Locksy - Complete Technical Documentation

**Version:** 1.0.0+2  
**Last Updated:** December 25, 2025  
**Project Type:** Secure End-to-End Encrypted Messaging Application

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Technology Stack](#2-technology-stack)
3. [System Architecture](#3-system-architecture)
4. [Encryption & Security](#4-encryption--security)
5. [Data Storage](#5-data-storage)
6. [Real-Time Communication](#6-real-time-communication)
7. [Authentication System](#7-authentication-system)
8. [Application Features](#8-application-features)
9. [API Reference](#9-api-reference)
10. [Deployment](#10-deployment)

---

## 1. Project Overview

### 1.1 Description

**Locksy** (internally named CryptoChat) is a privacy-focused secure messaging application that provides:

- End-to-end encrypted text messaging
- Encrypted media sharing (images, videos, audio, files)
- WebRTC-based voice and video calling
- Group messaging with encryption
- Real-time presence and typing indicators
- Push notifications for offline delivery

### 1.2 Design Philosophy

- **Zero-Knowledge Architecture**: Server cannot decrypt user messages
- **Client-Side Key Generation**: All cryptographic keys generated on device
- **Privacy by Default**: No metadata leakage, minimal data collection
- **Cross-Platform**: Single codebase for iOS, Android, Web, Desktop

### 1.3 Project Structure

```
locksy/
├── main/                          # Flutter Frontend Application
│   ├── lib/
│   │   ├── calc/                  # Calculator/Ninja Mode
│   │   ├── crypto/                # Encryption utilities
│   │   ├── global/                # Global configuration
│   │   ├── helpers/               # Helper functions
│   │   ├── models/                # Data models
│   │   ├── pages/                 # UI screens (40 pages)
│   │   ├── providers/             # State management
│   │   ├── push_providers/        # Push notification handlers
│   │   ├── routes/                # Navigation routes
│   │   ├── services/              # Business logic (17 services)
│   │   └── widgets/               # Reusable UI components
│   ├── assets/                    # Static assets
│   └── lang/                      # Localization (en, es)
│
└── locksy-backend-main/           # Node.js Backend Server
    ├── controllers/               # Request handlers
    ├── database/                  # Database configuration
    ├── functions/                 # Cloud functions
    ├── gateway/                   # API Gateway
    ├── helpers/                   # Utility functions
    ├── middlewares/               # Express middleware
    ├── models/                    # Mongoose schemas
    ├── routes/                    # API routes
    ├── services/                  # Microservices
    │   ├── analytics/
    │   ├── block-server/
    │   ├── cache/
    │   ├── cdn/
    │   ├── coordination/
    │   ├── email/
    │   ├── feed/
    │   ├── logging/
    │   ├── metadata-server/
    │   ├── notification/
    │   ├── partitioning/
    │   ├── queue/
    │   ├── search/
    │   ├── shard-manager/
    │   ├── storage/
    │   ├── tracing/
    │   ├── video/
    │   └── warehouse/
    └── sockets/                   # Socket.IO handlers
```

---

## 2. Technology Stack

### 2.1 Frontend Technologies

| Category | Technology | Version | Purpose |
|----------|------------|---------|---------|
| **Framework** | Flutter | ≥3.0.0 | Cross-platform UI |
| **Language** | Dart | Latest | Application logic |
| **State Management** | Provider | ^6.0.5 | Reactive state |
| **Local Database** | SQLite (sqflite) | ^2.2.3 | Message storage |
| **Secure Storage** | flutter_secure_storage | ^8.0.0 | Keys & tokens |
| **Cryptography** | PointyCastle | ^3.0.1 | RSA encryption |
| **Additional Crypto** | encrypt | ^5.0.3 | AES encryption |
| **ASN.1 Parsing** | asn1lib | ^1.5.3 | Key format handling |
| **Real-time** | socket_io_client | ^2.0.3+1 | WebSocket client |
| **Video Calls** | flutter_webrtc | ^1.2.0 | WebRTC implementation |
| **HTTP Client** | Dio | ^5.4.1 | API requests |
| **HTTP Client** | http | ^1.2.2 | Simple HTTP |
| **Push Notifications** | firebase_messaging | Latest | FCM integration |
| **Local Notifications** | flutter_local_notifications | ^17.2.3 | Foreground alerts |
| **Video Player** | video_player | ^2.10.1 | Video playback |
| **Video Player UI** | chewie | ^1.8.5 | Video controls |
| **Audio Player** | audioplayers | Latest | Audio playback |
| **Audio Recording** | flutter_sound | ^9.28.0 | Voice messages |
| **Camera** | camera | ^0.11.0+2 | Photo/video capture |
| **Image Picker** | image_picker | ^1.0.2 | Gallery access |
| **Image Compress** | flutter_image_compress | ^2.0.4 | Image optimization |
| **Video Compress** | video_compress | ^3.1.2 | Video optimization |
| **File Picker** | file_picker | Latest | File selection |
| **QR Scanner** | mobile_scanner | ^5.0.0 | QR code reading |
| **QR Generator** | qr_flutter | ^4.0.0 | QR code display |
| **PIN Input** | pin_code_fields | ^8.0.1 | OTP input |
| **Permissions** | permission_handler | ^12.0.1 | Runtime permissions |
| **Path Provider** | path_provider | ^2.0.2 | File system paths |
| **Shared Preferences** | shared_preferences | ^2.2.0 | Settings storage |
| **Connectivity** | connectivity_plus | ^6.0.5 | Network status |
| **URL Launcher** | url_launcher | ^6.0.4 | External links |
| **Share** | share_plus | ^10.0.2 | Content sharing |
| **Caching** | cached_network_image | ^3.3.0 | Image caching |
| **Animation** | rive | ^0.13.14 | Vector animations |
| **Emoji** | emoji_picker_flutter | ^3.1.0 | Emoji selection |
| **Carousel** | carousel_slider | Latest | Image galleries |
| **WebView** | webview_flutter | ^4.4.2 | In-app browser |
| **Logging** | logger | ^2.0.2 | Debug logging |
| **Date Formatting** | intl | ^0.20.2 | Localization |

### 2.2 Backend Technologies

| Category | Technology | Version | Purpose |
|----------|------------|---------|---------|
| **Runtime** | Node.js | ^22.6.0 | Server runtime |
| **Framework** | Express | ^4.17.1 | Web framework |
| **Database** | MongoDB | via Mongoose ^5.11.8 | Primary database |
| **Cache** | Redis | via ioredis ^5.3.2 | Caching & sessions |
| **Message Queue** | RabbitMQ | via amqplib ^0.10.3 | Async processing |
| **Search Engine** | Elasticsearch | ^16.7.3 | Full-text search |
| **Object Storage** | MinIO | via minio ^7.1.3 | File storage |
| **Cloud Storage** | AWS S3 | via aws-sdk ^2.1490.0 | CDN storage |
| **Real-time** | Socket.IO | ^4.7.5 | WebSocket server |
| **Socket Scaling** | @socket.io/redis-adapter | ^8.2.1 | Multi-instance |
| **Authentication** | jsonwebtoken | ^9.0.1 | JWT tokens |
| **Password Hashing** | bcryptjs | ^2.4.3 | Secure hashing |
| **Push Notifications** | firebase-admin | ^12.1.0 | FCM server |
| **Email** | nodemailer | ^6.5.0 | Email sending |
| **File Upload** | multer | ^1.4.2 | Multipart handling |
| **Video Processing** | fluent-ffmpeg | ^2.1.2 | Video transcoding |
| **FFmpeg Binary** | ffmpeg-static | ^5.2.0 | FFmpeg bundled |
| **Validation** | express-validator | ^6.9.0 | Input validation |
| **Rate Limiting** | express-rate-limit | ^6.8.1 | API throttling |
| **Rate Limit Store** | rate-limit-redis | ^3.0.1 | Redis-backed limits |
| **Security Headers** | helmet | ^7.1.0 | HTTP security |
| **Compression** | compression | ^1.7.4 | Response gzip |
| **CORS** | cors | ^2.8.5 | Cross-origin |
| **Cookie Parsing** | cookie-parser | ^1.4.7 | Cookie handling |
| **Proxy Middleware** | http-proxy-middleware | ^2.0.6 | API gateway |
| **Tracing** | @opentelemetry/sdk-node | ^0.45.0 | Distributed tracing |
| **Metrics** | prom-client | ^15.1.0 | Prometheus metrics |
| **Jaeger Export** | @opentelemetry/exporter-jaeger | ^1.15.0 | Trace export |
| **Logging** | pino | ^8.16.0 | JSON logging |
| **Logging Pretty** | pino-pretty | ^10.2.3 | Dev logging |
| **Logging Alt** | winston | ^3.11.0 | Alternative logger |
| **Scheduling** | node-cron | ^3.0.3 | Cron jobs |
| **UUID** | uuid | ^9.0.1 | Unique IDs |
| **HTTP Fetch** | node-fetch | ^2.7.0 | Server HTTP |
| **Zookeeper** | node-zookeeper-client | ^1.1.2 | Coordination |
| **MySQL** | mysql2 | ^3.9.7 | Optional SQL |

---

## 3. System Architecture

### 3.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              CLIENT LAYER                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│    ┌────────────────┐  ┌────────────────┐  ┌────────────────┐              │
│    │   iOS App      │  │  Android App   │  │   Desktop App  │              │
│    │   (Flutter)    │  │   (Flutter)    │  │   (Flutter)    │              │
│    └───────┬────────┘  └───────┬────────┘  └───────┬────────┘              │
│            │                   │                   │                        │
│            └───────────────────┼───────────────────┘                        │
│                                │                                            │
│                    ┌───────────▼───────────┐                               │
│                    │    Service Layer      │                               │
│                    │  ┌─────────────────┐  │                               │
│                    │  │  AuthService    │  │                               │
│                    │  │  SocketService  │  │                               │
│                    │  │  CryptoService  │  │                               │
│                    │  │  ChatService    │  │                               │
│                    │  └─────────────────┘  │                               │
│                    └───────────┬───────────┘                               │
│                                │                                            │
└────────────────────────────────┼────────────────────────────────────────────┘
                                 │
              ┌──────────────────┼──────────────────┐
              │ HTTPS REST API   │  WSS Socket.IO   │
              └──────────────────┼──────────────────┘
                                 │
┌────────────────────────────────┼────────────────────────────────────────────┐
│                          SERVER LAYER                                        │
├────────────────────────────────┼────────────────────────────────────────────┤
│                                │                                            │
│                    ┌───────────▼───────────┐                               │
│                    │   Load Balancer /     │                               │
│                    │   API Gateway         │                               │
│                    └───────────┬───────────┘                               │
│                                │                                            │
│           ┌────────────────────┼────────────────────┐                      │
│           │                    │                    │                      │
│    ┌──────▼──────┐     ┌──────▼──────┐     ┌──────▼──────┐               │
│    │  Worker 1   │     │  Worker 2   │     │  Worker N   │               │
│    │  (Express)  │     │  (Express)  │     │  (Express)  │               │
│    └──────┬──────┘     └──────┬──────┘     └──────┬──────┘               │
│           │                    │                    │                      │
│           └────────────────────┼────────────────────┘                      │
│                                │                                            │
│    ┌───────────────────────────┼───────────────────────────┐               │
│    │                    SERVICES                           │               │
│    │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │               │
│    │  │Metadata  │ │  Block   │ │  Shard   │ │  Video   │ │               │
│    │  │Server    │ │  Server  │ │ Manager  │ │ Workers  │ │               │
│    │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ │               │
│    └───────────────────────────┬───────────────────────────┘               │
│                                │                                            │
└────────────────────────────────┼────────────────────────────────────────────┘
                                 │
┌────────────────────────────────┼────────────────────────────────────────────┐
│                          DATA LAYER                                          │
├────────────────────────────────┼────────────────────────────────────────────┤
│                                │                                            │
│    ┌──────────┐  ┌──────────┐  │  ┌──────────┐  ┌──────────┐              │
│    │ MongoDB  │  │  Redis   │◄─┴─►│Elasticsearch│ │ RabbitMQ │              │
│    │(Primary) │  │ (Cache)  │     │ (Search)  │  │ (Queue)  │              │
│    └──────────┘  └──────────┘     └──────────┘  └──────────┘              │
│                                                                              │
│    ┌──────────────────────────────────────────────────────────┐            │
│    │              MinIO / S3 (Object Storage)                  │            │
│    │  ├─ Media files (images, videos, audio)                   │            │
│    │  ├─ User avatars                                          │            │
│    │  └─ Encrypted file attachments                            │            │
│    └──────────────────────────────────────────────────────────┘            │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
                                 │
                                 │
┌────────────────────────────────┼────────────────────────────────────────────┐
│                       EXTERNAL SERVICES                                      │
├────────────────────────────────┼────────────────────────────────────────────┤
│    ┌──────────────────────────┐│┌──────────────────────────┐               │
│    │  Firebase Cloud          ││ │        SMTP             │               │
│    │  Messaging (FCM)         ││ │   (Email Service)       │               │
│    │  - Push notifications    ││ │   - OTP delivery        │               │
│    │  - VoIP (iOS)            ││ │   - Password reset      │               │
│    └──────────────────────────┘│└──────────────────────────┘               │
│                                │                                            │
│    ┌──────────────────────────┐│                                           │
│    │       ICE/TURN           ││                                           │
│    │   (WebRTC Relay)         ││                                           │
│    │   - NAT traversal        ││                                           │
│    └──────────────────────────┘│                                           │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Frontend Architecture (Flutter)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         FLUTTER APP ARCHITECTURE                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                        PRESENTATION LAYER                            │   │
│   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────┐  │   │
│   │  │ HomePage    │  │ ChatPage    │  │ CallPage    │  │ Settings  │  │   │
│   │  │ LoginPage   │  │ GroupChat   │  │ IncomingCall│  │ Profile   │  │   │
│   │  │ RegisterPage│  │ ForwardPage │  │ ActiveCall  │  │ Contacts  │  │   │
│   │  └─────────────┘  └─────────────┘  └─────────────┘  └───────────┘  │   │
│   │                              │                                       │   │
│   │  ┌───────────────────────────▼───────────────────────────────────┐  │   │
│   │  │                    WIDGETS (Reusable)                          │  │   │
│   │  │  ChatMessage │ InputText │ QRViewer │ VideoPlayer │ Gallery   │  │   │
│   │  └───────────────────────────────────────────────────────────────┘  │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                      │                                       │
│   ┌──────────────────────────────────▼──────────────────────────────────┐   │
│   │                      STATE MANAGEMENT LAYER                          │   │
│   │  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐           │   │
│   │  │ ChatProvider  │  │ CallProvider  │  │ GroupProvider │           │   │
│   │  │ - messages    │  │ - callState   │  │ - groups      │           │   │
│   │  │ - contacts    │  │ - webRTC      │  │ - members     │           │   │
│   │  └───────┬───────┘  └───────┬───────┘  └───────┬───────┘           │   │
│   │          │                  │                  │                    │   │
│   │  ┌───────▼───────┐  ┌───────▼───────┐  ┌───────▼───────┐           │   │
│   │  │  DBProvider   │  │ socket events │  │  DBProvider   │           │   │
│   │  └───────────────┘  └───────────────┘  └───────────────┘           │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                      │                                       │
│   ┌──────────────────────────────────▼──────────────────────────────────┐   │
│   │                         SERVICE LAYER                                │   │
│   │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐   │   │
│   │  │ AuthService │ │SocketService│ │ ChatService │ │ FeedService │   │   │
│   │  │ - login     │ │ - connect   │ │ - encrypt   │ │ - stories   │   │   │
│   │  │ - register  │ │ - emit      │ │ - decrypt   │ │ - posts     │   │   │
│   │  │ - OTP       │ │ - listen    │ │ - messages  │ │             │   │   │
│   │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘   │   │
│   │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐   │   │
│   │  │CryptoService│ │FileCacheServ│ │SearchService│ │ CDNService  │   │   │
│   │  │ - RSA keys  │ │ - download  │ │ - users     │ │ - uploads   │   │   │
│   │  │ - encrypt   │ │ - cache     │ │ - content   │ │ - media     │   │   │
│   │  │ - decrypt   │ │ - verify    │ │             │ │             │   │   │
│   │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘   │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                      │                                       │
│   ┌──────────────────────────────────▼──────────────────────────────────┐   │
│   │                         STORAGE LAYER                                │   │
│   │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐     │   │
│   │  │  Secure Storage │  │     SQLite      │  │ SharedPreferences│     │   │
│   │  │  - JWT token    │  │  - Messages     │  │  - Settings      │     │   │
│   │  │  - Private key  │  │  - Contacts     │  │  - Preferences   │     │   │
│   │  │  - Public key   │  │  - Groups       │  │  - Language      │     │   │
│   │  └─────────────────┘  └─────────────────┘  └─────────────────┘     │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 3.3 Backend Architecture (Node.js)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      NODE.JS BACKEND ARCHITECTURE                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                         GATEWAY LAYER                                │   │
│   │  ┌─────────────────────────────────────────────────────────────┐    │   │
│   │  │                    API Gateway (Optional)                    │    │   │
│   │  │  - Route proxying    - Load balancing    - Rate limiting    │    │   │
│   │  └─────────────────────────────────────────────────────────────┘    │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                      │                                       │
│   ┌──────────────────────────────────▼──────────────────────────────────┐   │
│   │                       MIDDLEWARE STACK                               │   │
│   │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ │   │
│   │  │Helmet  │ │ CORS   │ │Compress│ │BodyPrs │ │ Logger │ │Tracing │ │   │
│   │  └────────┘ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘ │   │
│   │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐                       │   │
│   │  │RateLim │ │Sanitize│ │ Cache  │ │JWT Auth│                       │   │
│   │  └────────┘ └────────┘ └────────┘ └────────┘                       │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                      │                                       │
│   ┌──────────────────────────────────▼──────────────────────────────────┐   │
│   │                         ROUTE LAYER                                  │   │
│   │  /api/login     │ /api/usuarios  │ /api/contactos │ /api/grupos    │   │
│   │  /api/mensajes  │ /api/archivos  │ /api/solicitudes│ /api/search   │   │
│   │  /api/feed      │ /api/cdn       │ /api/analytics │ /health        │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                      │                                       │
│   ┌──────────────────────────────────▼──────────────────────────────────┐   │
│   │                       CONTROLLER LAYER                               │   │
│   │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐   │   │
│   │  │ AuthCtrl    │ │ UsuarioCtrl │ │ ContactoCtrl│ │  GrupoCtrl  │   │   │
│   │  │ MensajeCtrl │ │ UploadCtrl  │ │ SearchCtrl  │ │  SocketCtrl │   │   │
│   │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘   │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                      │                                       │
│   ┌──────────────────────────────────▼──────────────────────────────────┐   │
│   │                        MODEL LAYER (Mongoose)                        │   │
│   │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐   │   │
│   │  │  Usuario    │ │   Mensaje   │ │  Contacto   │ │    Grupo    │   │   │
│   │  │  - email    │ │ - ciphertext│ │ - userId    │ │ - codigo    │   │   │
│   │  │  - publicKey│ │ - de/para   │ │ - publicKey │ │ - publicKey │   │   │
│   │  │  - fcmToken │ │ - type      │ │             │ │ - members   │   │   │
│   │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘   │   │
│   │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                   │   │
│   │  │GrupoUsuario │ │RefreshToken │ │   Pago      │                   │   │
│   │  │ - grupo     │ │ - tokenHash │ │ - amount    │                   │   │
│   │  │ - usuario   │ │ - expiresAt │ │ - status    │                   │   │
│   │  └─────────────┘ └─────────────┘ └─────────────┘                   │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                      │                                       │
│   ┌──────────────────────────────────▼──────────────────────────────────┐   │
│   │                     BACKGROUND WORKERS                               │   │
│   │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐     │   │
│   │  │Notification Wkr │  │   Email Worker  │  │  Video Worker   │     │   │
│   │  │ - FCM push      │  │ - OTP emails    │  │ - Transcode     │     │   │
│   │  │ - Call alerts   │  │ - Password reset│  │ - Thumbnails    │     │   │
│   │  └─────────────────┘  └─────────────────┘  └─────────────────┘     │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Encryption & Security

### 4.1 Cryptographic Algorithms

| Purpose | Algorithm | Key Size | Notes |
|---------|-----------|----------|-------|
| **Message Encryption** | RSA-OAEP | 2048 bits | End-to-end encryption |
| **Symmetric Encryption** | AES-CBC | 256 bits | File/local encryption |
| **Private Key Storage** | AES-256-GCM | 256 bits | Password-protected |
| **Key Derivation** | PBKDF2-SHA256 | 256 bits | 100,000 iterations |
| **Password Hashing** | bcrypt | N/A | Salted hashing |
| **Digital Signatures** | RSA-SHA256 | 2048 bits | Message signing |
| **Token Signing** | HMAC-SHA256 | 256 bits | JWT tokens |
| **Refresh Token** | Crypto Random | 512 bits | Token generation |
| **Token Storage** | SHA-256 | 256 bits | Hash before storing |

### 4.2 RSA Key Generation (Client-Side)

```dart
// Key generation parameters
- Algorithm: RSA
- Key size: 2048 bits
- Public exponent: 65537 (0x10001)
- Random source: Fortuna PRNG (cryptographically secure)
- Storage: Secure Storage (iOS Keychain / Android Keystore)
```

**Key Format Handling:**
- Internal storage: ASN.1 Base64 format
- Backend communication: PEM format (X.509 SubjectPublicKeyInfo)
- Automatic format conversion between client and server

### 4.3 Message Encryption Flow

```
SENDER DEVICE:
┌─────────────────────────────────────────────────────────────────┐
│ 1. User types message                                           │
│ 2. Retrieve recipient's public key from contact                 │
│ 3. Convert public key from PEM to RSAPublicKey object           │
│ 4. Encrypt message using RSA-OAEP:                              │
│    - Input: UTF-8 encoded plaintext                             │
│    - Padding: OAEP (Optimal Asymmetric Encryption Padding)      │
│    - Block processing for messages > key size                   │
│ 5. Base64 encode ciphertext                                     │
│ 6. Send via Socket.IO with type metadata                        │
└─────────────────────────────────────────────────────────────────┘

SERVER (Zero-Knowledge):
┌─────────────────────────────────────────────────────────────────┐
│ 1. Receive encrypted message (ciphertext only)                  │
│ 2. Validate ciphertext format (min 100 bytes Base64)            │
│ 3. Store in MongoDB without decryption                          │
│ 4. Forward to recipient via Socket.IO                           │
│ 5. If offline: send FCM push (no message content)               │
└─────────────────────────────────────────────────────────────────┘

RECIPIENT DEVICE:
┌─────────────────────────────────────────────────────────────────┐
│ 1. Receive encrypted message via Socket.IO                      │
│ 2. Store ciphertext in SQLite                                   │
│ 3. Retrieve own private key from Secure Storage                 │
│ 4. Convert private key to RSAPrivateKey object                  │
│ 5. Decrypt message using RSA-OAEP                               │
│ 6. Display plaintext in chat UI                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 4.4 Private Key Protection (Server Storage)

For cross-device login, private keys can be optionally stored on the server encrypted with the user's password:

```javascript
// Encryption parameters
ALGORITHM: 'aes-256-gcm'
PBKDF2_ITERATIONS: 100000
KEY_LENGTH: 32 bytes (256 bits)
SALT_LENGTH: 16 bytes (128 bits)
IV_LENGTH: 12 bytes (96 bits)
TAG_LENGTH: 16 bytes (128 bits)

// Storage format (Base64 encoded)
┌────────────┬─────────┬─────────┬────────────────────┐
│    Salt    │   IV    │   Tag   │   Encrypted Data   │
│  16 bytes  │ 12 bytes│ 16 bytes│     Variable       │
└────────────┴─────────┴─────────┴────────────────────┘

// Security notes:
- Server NEVER has plaintext private key
- Decryption only possible with correct password
- Password never transmitted in plaintext
- Each encryption uses unique random salt and IV
```

### 4.5 Security Headers (Helmet.js)

```javascript
// Content Security Policy
contentSecurityPolicy: {
  defaultSrc: ["'self'"],
  styleSrc: ["'self'", "'unsafe-inline'"],
  scriptSrc: ["'self'", "'unsafe-inline'", "'unsafe-eval'"],
  imgSrc: ["'self'", "data:", "https:"],
  connectSrc: ["'self'"],
  fontSrc: ["'self'"],
  objectSrc: ["'none'"],
  mediaSrc: ["'self'"],
  frameSrc: ["'none'"]
}

// HTTP Strict Transport Security
hsts: {
  maxAge: 31536000,        // 1 year
  includeSubDomains: true,
  preload: true
}

// Additional headers
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
```

---

## 5. Data Storage

### 5.1 MongoDB Schemas

#### Usuario (User)
```javascript
{
  codigoContacto: String,          // Unique contact code for sharing
  nombre: String,                   // Display name (required)
  email: String,                    // Email (required, unique)
  password: String,                 // bcrypt hashed (optional, set after OTP)
  lastSeen: Date,                   // Last activity timestamp
  online: Boolean,                  // Online status
  firebaseid: String,               // FCM token for push notifications
  encryptedPrivateKey: String,      // Password-encrypted private key
  publicKey: String,                // RSA public key (PEM format)
  avatar: String,                   // Avatar URL
  blockUsers: [ObjectId],           // Blocked user references
  
  // Email verification
  emailVerified: Boolean,
  otpCode: String,                  // 6-digit code (hidden in queries)
  otpExpiresAt: Date,
  otpAttempts: Number,
  
  // Password reset
  resetOtpCode: String,             // Separate from registration OTP
  resetOtpExpiresAt: Date,
  resetOtpAttempts: Number,
  resetOtpVerified: Boolean
}
```

#### Mensaje (Message)
```javascript
{
  grupo: ObjectId,                  // Group reference (null for DM)
  de: String,                       // Sender UID
  para: String,                     // Recipient UID or group code
  mensaje: {                        // Message content object
    ciphertext: String,             // Base64 encrypted message (required)
    type: String,                   // 'text'|'image'|'video'|'audio'|'file'
    fileUrl: String,                // Optional file URL
    fileSize: Number,               // Optional file size
    fileName: String,               // Optional file name
    mimeType: String,               // Optional MIME type
    replyTo: ObjectId,              // Optional reply reference
    forwarded: Boolean              // Optional forwarded flag
  },
  send: Boolean,                    // Delivery status
  incognito: Boolean,               // Incognito mode flag
  usuario: ObjectId,                // Sender user reference
  forwarded: Boolean,               // Forwarded message
  reply: Boolean,                   // Reply message
  parentType: String,               // Original message type
  parentSender: String,             // Original sender
  parentContent: String,            // Original content preview
  timestamps: true                  // createdAt, updatedAt
}

// Indexes
{ de: 1, para: 1, createdAt: -1 }
{ para: 1, createdAt: -1 }
{ grupo: 1, createdAt: -1 }
```

#### RefreshToken
```javascript
{
  user: ObjectId,                   // User reference
  tokenHash: String,                // SHA-256 hash of token
  issuedAt: Date,                   // Issue timestamp
  expiresAt: Date,                  // Expiration timestamp
  revoked: Boolean,                 // Revocation status
  revokedAt: Date,                  // Revocation timestamp
  deviceId: String,                 // Device identifier
  userAgent: String,                // Browser/app user agent
  ipAddress: String                 // Client IP address
}

// Methods
- hashToken(token)                  // Static: hash token before storage
- findByToken(token)                // Static: find by token hash
- isValid()                         // Check if not expired/revoked
- revoke()                          // Mark as revoked
```

### 5.2 SQLite Schema (Client-Side)

```sql
-- Messages table
CREATE TABLE mensajes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  de TEXT NOT NULL,
  para TEXT NOT NULL,
  mensaje TEXT NOT NULL,           -- Encrypted ciphertext
  tipo TEXT DEFAULT 'text',
  createdAt TEXT NOT NULL,
  read INTEGER DEFAULT 0,
  grupo_id TEXT,
  reply_to INTEGER,
  forwarded INTEGER DEFAULT 0
);

-- Contacts table
CREATE TABLE contactos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uid TEXT NOT NULL UNIQUE,
  nombre TEXT,
  avatar TEXT,
  publicKey TEXT,                   -- For encryption
  online INTEGER DEFAULT 0,
  lastSeen TEXT
);

-- Groups table
CREATE TABLE grupos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  codigo TEXT NOT NULL UNIQUE,
  nombre TEXT,
  avatar TEXT,
  publicKey TEXT,
  descripcion TEXT
);
```

---

## 6. Real-Time Communication

### 6.1 Socket.IO Configuration

```javascript
// Server configuration
const socketIOConfig = {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  },
  adapter: RedisAdapter          // For multi-instance scaling
};

// Connection settings (Express)
server.keepAliveTimeout = 65000;
server.headersTimeout = 66000;
server.maxHeadersCount = 2000;
```

### 6.2 Socket Events Reference

#### Authentication Events
| Event | Direction | Payload | Description |
|-------|-----------|---------|-------------|
| `connect` | Client→Server | Headers: x-token, firebaseid | Initial connection |
| `disconnect` | Automatic | - | Connection lost |
| `setup` | Client→Server | `{codigo}` | Join user room |

#### Messaging Events
| Event | Direction | Payload | Description |
|-------|-----------|---------|-------------|
| `mensaje-personal` | Bidirectional | Message object | Private message |
| `mensaje-grupal` | Bidirectional | Message object | Group message |
| `message-received-ack` | Client→Server | `{messageId, status, payload}` | Delivery ACK |
| `recibido-cliente` | Bidirectional | `{para, messageId}` | Read receipt |
| `userTyping` | Bidirectional | `{to, user}` | Typing indicator |
| `modo-incognito` | Bidirectional | Message object | Incognito message |

#### Call Events
| Event | Direction | Payload | Description |
|-------|-----------|---------|-------------|
| `startCall` | Client→Server | `{recipientId, callerId, isVideoCall, roomId}` | Initiate call |
| `newOffer` | Bidirectional | `{recipientId, sdp, type, callerId, isVideoCall}` | WebRTC offer |
| `answer` | Bidirectional | `{recipientId, sdp, type}` | WebRTC answer |
| `candidate` | Bidirectional | `{recipientId, candidate, sdpMid, sdpMLineIndex}` | ICE candidate |
| `acceptNewCall` | Bidirectional | `{recipientId, callerId, isVideoCall}` | Accept call |
| `call-accepted` | Bidirectional | `{callerId, receiverId, roomId, isVideoCall}` | Call accepted |
| `endCall` | Bidirectional | `{to, from}` | End call |
| `hangup` | Bidirectional | `{recipientId, codigo}` | Hang up |
| `buzz` | Client→Server | `{recipientId}` | Buzz/ring again |

#### Status Events
| Event | Direction | Payload | Description |
|-------|-----------|---------|-------------|
| `usuario-conectado` | Server→Client | User ID | User online |
| `usuario-desconectado` | Server→Client | User ID | User offline |
| `callCheck` | Bidirectional | `{to, from}` | Check call status |

### 6.3 WebRTC Implementation

```
WEBRTC CALL FLOW
================

1. OFFER PHASE (Caller)
   ┌─────────────────────────────────────────┐
   │ a. Request camera/microphone permission │
   │ b. Create RTCPeerConnection             │
   │ c. Get local media stream               │
   │ d. Add tracks to peer connection        │
   │ e. Create SDP offer                     │
   │ f. Set local description                │
   │ g. Emit 'newOffer' via Socket.IO        │
   └─────────────────────────────────────────┘

2. SIGNALING (Server)
   ┌─────────────────────────────────────────┐
   │ a. Forward offer to recipient room      │
   │ b. Send FCM push if offline (data-only) │
   └─────────────────────────────────────────┘

3. ANSWER PHASE (Recipient)
   ┌─────────────────────────────────────────┐
   │ a. Receive 'newOffer' event             │
   │ b. Show incoming call UI                │
   │ c. User accepts call                    │
   │ d. Create RTCPeerConnection             │
   │ e. Set remote description (offer)       │
   │ f. Get local media stream               │
   │ g. Create SDP answer                    │
   │ h. Set local description                │
   │ i. Emit 'answer' via Socket.IO          │
   └─────────────────────────────────────────┘

4. ICE NEGOTIATION (Both)
   ┌─────────────────────────────────────────┐
   │ a. Generate ICE candidates              │
   │ b. Send each candidate via 'candidate'  │
   │ c. Receive remote candidates            │
   │ d. Add to peer connection               │
   └─────────────────────────────────────────┘

5. CONNECTED
   ┌─────────────────────────────────────────┐
   │ Direct P2P media streaming              │
   │ (audio/video flows directly between     │
   │  devices, bypassing server)             │
   └─────────────────────────────────────────┘
```

---

## 7. Authentication System

### 7.1 Registration Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     REGISTRATION FLOW                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. USER ENTERS EMAIL & NAME                                     │
│     └─► App calls POST /api/login/send-otp                      │
│                                                                  │
│  2. SERVER SENDS OTP                                             │
│     ├─► Generate 6-digit OTP                                     │
│     ├─► Store hashed OTP with 10-min expiry                      │
│     ├─► Send email via nodemailer                                │
│     └─► Return success (no OTP in response)                      │
│                                                                  │
│  3. USER ENTERS OTP CODE                                         │
│     └─► App calls POST /api/login/verify-otp                    │
│                                                                  │
│  4. SERVER VERIFIES OTP                                          │
│     ├─► Check OTP matches and not expired                        │
│     ├─► Check attempt count < max                                │
│     ├─► Mark email as verified                                   │
│     └─► Return verification token                                │
│                                                                  │
│  5. USER SETS PASSWORD                                           │
│     └─► App calls POST /api/login/new                           │
│                                                                  │
│  6. SERVER COMPLETES REGISTRATION                                │
│     ├─► Verify OTP token                                         │
│     ├─► Hash password with bcrypt                                │
│     ├─► Validate RSA public key format                           │
│     ├─► Optional: Store encrypted private key                    │
│     ├─► Generate JWT access token (15 min)                       │
│     ├─► Generate refresh token (7 days)                          │
│     └─► Return tokens + user data                                │
│                                                                  │
│  7. CLIENT STORES CREDENTIALS                                    │
│     ├─► Store JWT in Secure Storage                              │
│     ├─► Store refresh token (httpOnly cookie or storage)         │
│     ├─► Store RSA keys in Secure Storage                         │
│     └─► Initialize Socket.IO connection                          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 7.2 Login Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        LOGIN FLOW                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. USER ENTERS CREDENTIALS                                      │
│     └─► App calls POST /api/login                               │
│                                                                  │
│  2. SERVER VALIDATES                                             │
│     ├─► Find user by email                                       │
│     ├─► Verify password with bcrypt                              │
│     ├─► Update FCM token if provided                             │
│     └─► Update lastSeen timestamp                                │
│                                                                  │
│  3. TOKEN GENERATION                                             │
│     ├─► Generate access token (JWT, 15 min)                      │
│     ├─► Generate refresh token (random, 7 days)                  │
│     ├─► Store refresh token hash in DB                           │
│     └─► Return tokens + user + public key                        │
│                                                                  │
│  4. KEY HANDLING (Client)                                        │
│     ├─► If server has encryptedPrivateKey:                       │
│     │   └─► Decrypt with password, store locally                 │
│     ├─► If no server key but local key exists:                   │
│     │   └─► Use existing local key                               │
│     └─► If no keys anywhere:                                     │
│         └─► Generate new key pair, upload public key             │
│                                                                  │
│  5. SOCKET CONNECTION                                            │
│     ├─► Initialize Socket.IO with token                          │
│     ├─► Join user room                                           │
│     └─► Sync pending messages                                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 7.3 Token Refresh Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    TOKEN REFRESH FLOW                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. ACCESS TOKEN EXPIRES (after 15 minutes)                      │
│     └─► 401 response or proactive refresh                       │
│                                                                  │
│  2. CLIENT REQUESTS REFRESH                                      │
│     └─► POST /api/login/refresh with refresh token              │
│                                                                  │
│  3. SERVER VALIDATES REFRESH TOKEN                               │
│     ├─► Hash received token                                      │
│     ├─► Find matching token in DB                                │
│     ├─► Check not expired or revoked                             │
│     └─► Verify device ID matches (optional)                      │
│                                                                  │
│  4. TOKEN ROTATION (Security measure)                            │
│     ├─► Revoke old refresh token                                 │
│     ├─► Generate new access token                                │
│     ├─► Generate new refresh token                               │
│     └─► Store new refresh token hash                             │
│                                                                  │
│  5. RETURN NEW TOKENS                                            │
│     ├─► New access token (15 min)                                │
│     ├─► New refresh token (7 days)                               │
│     └─► Set httpOnly cookie (if applicable)                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 7.4 Password Reset Flow

```
1. Request Reset    → POST /api/login/forgot-password {email}
2. Receive OTP      → Email sent with 6-digit code
3. Verify OTP       → POST /api/login/verify-reset-otp {email, otpCode}
4. Set New Password → POST /api/login/reset-password {email, newPassword, otpCode}
5. Re-encrypt Keys  → If encrypted private key exists, re-encrypt with new password
```

---

## 8. Application Features

### 8.1 Core Features

| Feature | Description | Implementation |
|---------|-------------|----------------|
| **E2E Encrypted Chat** | All messages encrypted client-side | RSA-OAEP with 2048-bit keys |
| **Media Sharing** | Images, videos, audio, files | Encrypted metadata, CDN storage |
| **Voice Calls** | P2P audio calls | WebRTC with ICE/TURN |
| **Video Calls** | P2P video calls | WebRTC with adaptive bitrate |
| **Group Chat** | Multi-user conversations | Group encryption keys |
| **Message Replies** | Reply to specific messages | Parent reference in DB |
| **Message Forwarding** | Forward to other chats | Forwarded flag preserved |
| **Typing Indicators** | Real-time typing status | Socket event with timeout |
| **Read Receipts** | Message read confirmation | Acknowledgment events |
| **Online Status** | User presence tracking | Socket connection status |
| **Push Notifications** | Offline message alerts | FCM (Android/iOS) |
| **Call Notifications** | Incoming call alerts | Data-only FCM + custom UI |

### 8.2 Security Features

| Feature | Description | Implementation |
|---------|-------------|----------------|
| **Calculator Mode** | Disguised app launcher | Hidden PIN entry |
| **Ninja Mode** | Quick app switching | Calculator facade |
| **Incognito Messages** | No persistence option | Server doesn't store |
| **Disappearing Messages** | Auto-delete after time | Client-side cleanup |
| **User Blocking** | Block unwanted contacts | Server-side filter |
| **Screenshot Protection** | Prevent screenshots | Platform APIs (limited) |

### 8.3 Media Features

| Feature | Description | Technical Details |
|---------|-------------|-------------------|
| **Image Compression** | Reduce file size | flutter_image_compress |
| **Video Compression** | Reduce file size | video_compress / FFmpeg |
| **Video Thumbnails** | Preview generation | video_thumbnail |
| **Audio Recording** | Voice messages | flutter_sound |
| **File Caching** | Local storage | FileCacheService |
| **Gallery View** | Image browsing | photo_view |
| **Video Player** | In-app playback | chewie + video_player |

### 8.4 User Management

| Feature | Description | Endpoint |
|---------|-------------|----------|
| **Registration** | Email + OTP verification | POST /api/login/new |
| **Login** | Email + password | POST /api/login |
| **Password Reset** | Email + OTP flow | POST /api/login/forgot-password |
| **Profile Update** | Name, avatar, password | PUT /api/usuarios |
| **QR Contact Share** | Generate shareable QR | Client-side generation |
| **Contact Search** | Find users | GET /api/search |

---

## 9. API Reference

### 9.1 Authentication Endpoints

```
POST /api/login
  Request:  { email, password, firebaseToken }
  Response: { ok, token, refreshToken, usuario }

POST /api/login/new
  Request:  { nombre, email, password, publicKey, referCode }
  Response: { ok, token, refreshToken, usuario }

POST /api/login/send-otp
  Request:  { email, nombre }
  Response: { ok, msg }

POST /api/login/verify-otp
  Request:  { email, otpCode }
  Response: { ok, token }

POST /api/login/forgot-password
  Request:  { email }
  Response: { ok, msg }

POST /api/login/verify-reset-otp
  Request:  { email, otpCode }
  Response: { ok, msg }

POST /api/login/reset-password
  Request:  { email, newPassword, otpCode }
  Response: { ok, msg }

POST /api/login/refresh
  Request:  { refreshToken } or cookie
  Response: { ok, token, refreshToken }

POST /api/login/logout
  Request:  Authorization header
  Response: { ok, msg }
```

### 9.2 User Endpoints

```
GET /api/usuarios
  Headers:  x-token
  Response: { ok, usuarios }

GET /api/usuarios/:uid
  Headers:  x-token
  Response: { ok, usuario }

PUT /api/usuarios
  Headers:  x-token
  Request:  { nombre, avatar, password }
  Response: { ok, usuario }

PUT /api/usuarios/fcm-token
  Headers:  x-token
  Request:  { fcmToken }
  Response: { ok, msg }
```

### 9.3 Message Endpoints

```
GET /api/mensajes/:de/:para
  Headers:  x-token
  Response: { ok, mensajes }

POST /api/mensajes
  Headers:  x-token
  Request:  { de, para, mensaje, tipo }
  Response: { ok, mensaje }

DELETE /api/mensajes/:mid
  Headers:  x-token
  Response: { ok, msg }
```

### 9.4 File Upload Endpoints

```
POST /api/archivos
  Headers:  x-token, Content-Type: multipart/form-data
  Body:     FormData with file
  Response: { ok, fileUrl }

GET /uploads/:filename
  Response: File stream

GET /CryptoChatfiles/:filename
  Response: File stream
```

### 9.5 Health Check Endpoints

```
GET /health
  Response: { ok, status, workerId, pid, uptime, timestamp }

GET /health/ready
  Response: { ok, status, checks: { database } }

GET /health/live
  Response: { ok, status, pid, uptime }
```

---

## 10. Deployment

### 10.1 Environment Variables

```bash
# Server
PORT=3000
NODE_ENV=production|development

# Database
MONGODB_CNN=mongodb://host:27017/locksy

# Redis
REDIS_URL=redis://host:6379

# Authentication
JWT_KEY=your-secret-key
ACCESS_TOKEN_EXPIRY=15m
REFRESH_TOKEN_EXPIRY_DAYS=7

# Scaling
ENABLE_CLUSTER=true|false
USE_GATEWAY=true|false

# CORS
ALLOWED_ORIGINS=https://app.example.com

# Storage
MINIO_ENDPOINT=minio.example.com
MINIO_ACCESS_KEY=accesskey
MINIO_SECRET_KEY=secretkey
MINIO_BUCKET=locksy-files

# Email
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=user@example.com
SMTP_PASS=password

# Firebase (use service account JSON file)
# locksy-app-firebase-adminsdk-*.json
```

### 10.2 Docker Deployment

```yaml
# docker-compose.yml services
services:
  api:
    build: .
    ports: ["3000:3000"]
    environment: [...]
    depends_on: [mongodb, redis, rabbitmq]
    
  mongodb:
    image: mongo:5
    volumes: [./data/mongo:/data/db]
    
  redis:
    image: redis:7-alpine
    
  rabbitmq:
    image: rabbitmq:3-management
    
  elasticsearch:
    image: elasticsearch:7.17.9
    
  minio:
    image: minio/minio
    command: server /data
    
  nginx:
    image: nginx:alpine
    ports: ["80:80", "443:443"]
```

### 10.3 Production Checklist

- [ ] Enable HTTPS/WSS
- [ ] Configure proper CORS origins
- [ ] Set up rate limiting
- [ ] Enable cluster mode for multi-CPU
- [ ] Configure Redis for Socket.IO scaling
- [ ] Set up MongoDB replica set
- [ ] Configure CDN for static assets
- [ ] Enable OpenTelemetry tracing
- [ ] Set up log aggregation
- [ ] Configure automated backups
- [ ] Set up health check monitoring
- [ ] Configure SSL certificates
- [ ] Enable HSTS preloading

---

## Document Information

| Field | Value |
|-------|-------|
| **Document Version** | 1.0 |
| **Application Version** | 1.0.0+2 |
| **Last Updated** | December 25, 2025 |
| **Author** | Locksy Development Team |
| **Technologies Analyzed** | 50+ Flutter packages, 40+ Node.js packages |
| **Total Pages (Screens)** | 40 |
| **Total Services (Frontend)** | 17 |
| **Total Microservices (Backend)** | 18 |

---

*This documentation is auto-generated from source code analysis. For the latest information, refer to the codebase.*
