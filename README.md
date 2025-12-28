# 📸 FotoFocus

**FotoFocus** is a mobile photography learning and community app built with **Flutter** and a **Node.js + Prisma** backend.  
It helps beginner photographers improve through **structured lessons**, **creative challenges**, and **community feedback**.

---

## 🚀 Key Features

- JWT-based authentication with email verification  
- Structured photography lessons with visual content  
- Photography challenges with photo submissions  
- Cloudinary-powered image uploads  
- Star-based photo rating system  
- Community feed with posts, likes, and comments  
- User profiles with posts, likes, and follow system  
- Secure account deletion with backend cascade cleanup  

---

## 🧱 Tech Stack

### Frontend
- Flutter  
- Provider (state management)

### Backend
- Node.js  
- Express  
- Prisma ORM  
- PostgreSQL  
- JWT Authentication  

### Services
- Cloudinary (image storage)  
- Resend / Gmail (email verification)

---

## 🏗 Architecture Highlights

- API-first architecture (no Firebase)  
- Clean separation of providers, services, and models  
- Single source of truth for feed and rating state  
- RESTful backend with well-defined Prisma relations  

---

## ⚙️ Quick Setup

```bash
# Backend
npm install
npx prisma migrate dev
npm run dev

# Frontend
flutter pub get
flutter run

