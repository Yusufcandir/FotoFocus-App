import express from "express";
import cors from "cors";
import multer from "multer";
import path from "path";
import fs from "fs";
import bcrypt from "bcrypt";
import crypto from "crypto";
import jwt from "jsonwebtoken";
import { PrismaClient } from "@prisma/client";
import { fileURLToPath } from "url";
import nodemailer from "nodemailer";
import "dotenv/config";


const prisma = new PrismaClient();
const app = express();
const PORT = process.env.PORT || 8080;


app.use(cors());
app.use(express.json());

// -------- paths / uploads --------
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const UPLOAD_DIR = path.join(__dirname, "uploads");
if (!fs.existsSync(UPLOAD_DIR)) fs.mkdirSync(UPLOAD_DIR, { recursive: true });

// serve uploaded images
app.use("/uploads", express.static(UPLOAD_DIR));

// -------- multer config --------
const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, UPLOAD_DIR),
  filename: (_req, file, cb) => {
    const safe = file.originalname.replace(/\s+/g, "_");
    cb(null, `${Date.now()}_${safe}`);
  },
});

const upload = multer({ storage });

// -------- auth helpers --------
function signToken(user) {
  return jwt.sign(
    { sub: user.id, email: user.email },
    process.env.JWT_SECRET || "DEV_SECRET_CHANGE_ME",
    { expiresIn: "7d" }
  );
}

function sha256(s) {
  return crypto.createHash("sha256").update(s).digest("hex");
}
function generate6DigitCode() {
  return String(crypto.randomInt(100000, 1000000));
}
function auth(req, res, next) {
  try {
    const header = req.headers.authorization || "";
    const token = header.startsWith("Bearer ") ? header.slice(7) : null;
    if (!token) return res.status(401).json({ message: "Missing token" });

    const payload = jwt.verify(token, process.env.JWT_SECRET || "DEV_SECRET_CHANGE_ME");
    // normalize user shape for easy checks
    req.user = { id: payload.sub, email: payload.email };
    next();
  } catch (e) {
    return res.status(401).json({ message: "Invalid token" });
  }
}
// optional auth middleware
function optionalAuth(req, _res, next) {
  try {
    const header = req.headers.authorization || "";
    const token = header.startsWith("Bearer ") ? header.slice(7) : null;
    if (!token) {
      req.user = null;
      return next();
    }
    const payload = jwt.verify(token, process.env.JWT_SECRET || "DEV_SECRET_CHANGE_ME");
    req.user = { id: payload.sub, email: payload.email };
    next();
  } catch {
    req.user = null;
    next();
  }
}

function publicUser(u) {
  return u
    ? { id: u.id, email: u.email, name: u.name, avatarUrl: u.avatarUrl, createdAt: u.createdAt }
    : null;
}


// -------- AUTH --------
// OPTIONAL: improve register to support confirmPassword coming from Flutter
app.post("/auth/login", async (req, res) => {
  try {
    const { email, password } = req.body || {};
    if (!email || !password) {
      return res.status(400).json({ message: "email and password required" });
    }

    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) return res.status(401).json({ message: "Invalid credentials" });

    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) return res.status(401).json({ message: "Invalid credentials" });

    // return only safe fields
    const safeUser = { id: user.id, email: user.email };

    const token = signToken(safeUser);
    return res.json({ token, user: safeUser });
  } catch (err) {
    console.error("LOGIN ERROR:", err);
    return res.status(500).json({ message: "Failed to login" });
  }
});




// POST /auth/forgot-password
app.post("/auth/forgot-password", async (req, res) => {
  try {
    const { email } = req.body || {};
    if (!email) return res.status(400).json({ message: "email required" });

    const user = await prisma.user.findUnique({ where: { email } });

    // Always respond OK (prevents account enumeration)
    if (!user) {
      return res.json({ message: "If the email exists, we sent a reset instruction." });
    }

    const token = crypto.randomBytes(32).toString("hex");
    const tokenHash = sha256(token);
    const expiresAt = new Date(Date.now() + 1000 * 60 * 15); // 15 minutes

    await prisma.passwordResetToken.create({
      data: { tokenHash, userId: user.id, expiresAt },
    });

    // TODO: send email here (nodemailer / resend / sendgrid)
    // For now: return token only in development so you can test
    const payload =
      process.env.NODE_ENV !== "production"
        ? { message: "Reset token created (DEV).", token }
        : { message: "If the email exists, we sent a reset instruction." };

    return res.json(payload);
  } catch (err) {
    console.error("FORGOT PASSWORD ERROR:", err);
    return res.status(500).json({ message: "Failed to request password reset" });
  }
});

// POST /auth/reset-password
app.post("/auth/reset-password", async (req, res) => {
  try {
    const { token, newPassword } = req.body || {};
    if (!token || !newPassword) {
      return res.status(400).json({ message: "token and newPassword required" });
    }
    if (newPassword.length < 6) {
      return res.status(400).json({ message: "Password must be at least 6 characters" });
    }

    const tokenHash = sha256(token);

    const record = await prisma.passwordResetToken.findUnique({
      where: { tokenHash },
    });

    if (!record || record.expiresAt < new Date()) {
      return res.status(400).json({ message: "Token is invalid or expired" });
    }

    const passwordHash = await bcrypt.hash(newPassword, 10);

    await prisma.user.update({
      where: { id: record.userId },
      data: { passwordHash },
    });

    await prisma.passwordResetToken.delete({
      where: { tokenHash },
    });

    return res.json({ message: "Password updated successfully" });
  } catch (err) {
    console.error("RESET PASSWORD ERROR:", err);
    return res.status(500).json({ message: "Failed to reset password" });
  }
});

app.post("/auth/register", async (req, res) => {
  try {
    const { email, password, confirmPassword } = req.body || {};
    if (!email || !password) {
      return res.status(400).json({ message: "email and password required" });
    }
    if (confirmPassword !== password) {
      return res.status(400).json({ message: "Passwords do not match" });
    }
    if (password.length < 6) {
      return res.status(400).json({ message: "Password must be at least 6 characters" });
    }

    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) return res.status(409).json({ message: "Email already exists" });

    const code = generate6DigitCode();
    const codeHash = sha256(code);
    const passwordHash = await bcrypt.hash(password, 10);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    // store pending registration (you must have PendingRegistration model in prisma)
    await prisma.pendingRegistration.upsert({
      where: { email },
      create: { email, passwordHash, codeHash, expiresAt, attempts: 0, lastSentAt: new Date() },
      update: { passwordHash, codeHash, expiresAt, attempts: 0, lastSentAt: new Date() },
    });

    await sendVerificationEmail(email, code);

    return res.json({ message: "Verification code sent." });
  } catch (err) {
    console.error("REGISTER REQUEST ERROR:", err);
    return res.status(500).json({ message: "Failed to send verification code" });
  }
});

app.post("/auth/register/request", async (req, res) => {
  try {
    const { email, password, confirmPassword } = req.body || {};

    if (!email || !password) {
      return res.status(400).json({ message: "email and password required" });
    }
    if (confirmPassword != null && confirmPassword !== password) {
      return res.status(400).json({ message: "Passwords do not match" });
    }

    // optional: basic password rule
    if (password.length < 6) {
      return res.status(400).json({ message: "Password must be at least 6 characters" });
    }

    // block if already registered
    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) return res.status(409).json({ message: "Email already exists" });

    // create/update pending registration
    const code = generate6DigitCode();
    const codeHash = sha256(code);
    const passwordHash = await bcrypt.hash(password, 10);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    // if pending exists, throttle resend (60s)
    const pending = await prisma.pendingRegistration.findUnique({ where: { email } });
    if (pending) {
      const msSinceLast = Date.now() - new Date(pending.lastSentAt).getTime();
      if (msSinceLast < 60 * 1000) {
        return res.status(429).json({ message: "Please wait before requesting another code." });
      }
    }

    await prisma.pendingRegistration.upsert({
      where: { email },
      create: {
        email,
        passwordHash,
        codeHash,
        expiresAt,
        attempts: 0,
        lastSentAt: new Date(),
      },
      update: {
        passwordHash,
        codeHash,
        expiresAt,
        attempts: 0,
        lastSentAt: new Date(),
      },
    });

    await sendVerificationEmail(email, code);

    return res.json({ message: "Verification code sent." });
  } catch (err) {
    console.error("REGISTER REQUEST ERROR:", err);
    return res.status(500).json({ message: "Failed to send verification code" });
  }
});


app.post("/auth/register/verify", async (req, res) => {
  try {
    const { email, code } = req.body || {};
    if (!email || !code) {
      return res.status(400).json({ message: "email and code required" });
    }

    const pending = await prisma.pendingRegistration.findUnique({ where: { email } });
    if (!pending) return res.status(400).json({ message: "No pending registration for this email." });

    if (pending.expiresAt < new Date()) {
      await prisma.pendingRegistration.delete({ where: { email } });
      return res.status(400).json({ message: "Code expired. Please register again." });
    }

    if (pending.attempts >= 5) {
      return res.status(429).json({ message: "Too many attempts. Please register again." });
    }

    if (sha256(String(code).trim()) !== pending.codeHash) {
      await prisma.pendingRegistration.update({
        where: { email },
        data: { attempts: { increment: 1 } },
      });
      return res.status(400).json({ message: "Invalid verification code." });
    }

    const user = await prisma.user.create({
      data: { email, passwordHash: pending.passwordHash },
      select: { id: true, email: true },
    });

    await prisma.pendingRegistration.delete({ where: { email } });

    const token = signToken(user);
    return res.json({ token, user });
  } catch (err) {
    console.error("REGISTER VERIFY ERROR:", err);
    return res.status(500).json({ message: "Failed to verify code" });
  }
});


// -------- CHALLENGES --------

// list challenges
app.get("/challenges", async (_req, res) => {
  try {
    const challenges = await prisma.challenge.findMany({
      orderBy: { createdAt: "desc" },
      include: {
        creator: { select: { id: true, email: true, name: true, avatarUrl: true } },
},

    });
    res.json(challenges);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Failed to load challenges" });
  }
});

// get one challenge
app.get("/challenges/:id", async (req, res) => {
  try {
    const id = Number(req.params.id);
    const challenge = await prisma.challenge.findUnique({
      where: { id },
      include: {
        creator: { select: { id: true, email: true, name: true, avatarUrl: true } },
},

    });
    if (!challenge) return res.status(404).json({ message: "Challenge not found" });
    res.json(challenge);
  } catch (err) {
    console.error(err);
    
    res.status(500).json({ message: "Failed to load challenge" });
  }
});


// create challenge (optional cover image: field name MUST be "cover")
app.post("/challenges", auth, upload.single("cover"), async (req, res) => {
  try {
    const { title, description } = req.body || {};
    if (!title || !title.trim()) {
      return res.status(400).json({ message: "title required" });
    }

    const coverUrl = req.file ? `/uploads/${req.file.filename}` : null;

    const challenge = await prisma.challenge.create({
      data: {
        title: title.trim(),
        description: (description ?? "").trim() || null,
        coverUrl,               // IMPORTANT: coverUrl
        creatorId: req.user.id, // owner
      },
    });

    res.json({ challenge });
  } catch (err) {
    console.error("CREATE CHALLENGE ERROR:", err);
    res.status(500).json({ message: "Failed to create challenge" });
  }
});
// delete challenge (only owner)
// delete challenge (only owner)
app.delete("/challenges/:id", auth, async (req, res) => {
  try {
    const challengeId = Number(req.params.id);
    if (!Number.isFinite(challengeId)) {
      return res.status(400).json({ message: "Invalid challenge id" });
    }

    const challenge = await prisma.challenge.findUnique({
      where: { id: challengeId },
      select: { creatorId: true },
    });

    if (!challenge) {
      return res.status(404).json({ message: "Challenge not found" });
    }

    if (challenge.creatorId !== req.user.id) {
      return res.status(403).json({ message: "Not allowed" });
    }

    // ✅ EVERYTHING that uses `tx` MUST be inside this block
    await prisma.$transaction(async (tx) => {
      // 1) delete ratings
      await tx.rating.deleteMany({
        where: { photo: { challengeId } },
      });

      // 2) delete comments
      await tx.comment.deleteMany({
        where: { photo: { challengeId } },
      });

      // 3) delete photos
      await tx.photo.deleteMany({
        where: { challengeId },
      });

      // 4) delete challenge
      await tx.challenge.delete({
        where: { id: challengeId },
      });
    });

    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Failed to delete challenge" });
  }
});



// update challenge (only owner)
app.put("/challenges/:id", auth, async (req, res) => {
  try {
    const challengeId = Number(req.params.id);
    if (!Number.isFinite(challengeId)) {
      return res.status(400).json({ message: "Invalid challenge id" });
    }

    const { title, description } = req.body;

    const challenge = await prisma.challenge.findUnique({
      where: { id: challengeId },
      select: { creatorId: true }, // ✅ FIX
    });

    if (!challenge) return res.status(404).json({ message: "Challenge not found" });

    if (challenge.creatorId !== req.user.id) { // ✅ FIX
      return res.status(403).json({ message: "Not allowed" });
    }

    const updated = await prisma.challenge.update({
      where: { id: challengeId },
      data: {
        ...(title != null ? { title } : {}),
        ...(description != null ? { description } : {}),
      },
    });

    res.json(updated);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Failed to update challenge" });
  }
});




// -------- PHOTOS (submissions) --------

// list photos under challenge
app.get("/challenges/:id/photos", async (req, res) => {
  try {
    const challengeId = Number(req.params.id);

    const photos = await prisma.photo.findMany({
      where: { challengeId },
      orderBy: { createdAt: "desc" },
      include: {
        user: { select: { id: true, email: true } },
        ratings: { select: { value: true } },
      },
    });

    // add avgRating + ratingCount fields for your Flutter model
    const mapped = photos.map((p) => {
      const ratingCount = p.ratings.length;
      const avgRating =
        ratingCount === 0
          ? 0
          : p.ratings.reduce((sum, r) => sum + r.value, 0) / ratingCount;

      return {
        id: p.id,
        challengeId: p.challengeId,
        imageUrl: p.imageUrl,
        caption: p.caption ?? "",
        userId: p.user.id,
        userEmail: p.user.email,
        createdAt: p.createdAt.toISOString(),
        avgRating,
        ratingCount,
      };
    });

    res.json(mapped);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Failed to load challenge photos" });
  }
});

// upload photo to challenge (field name MUST be "photo")
app.post("/challenges/:id/photos", auth, upload.single("photo"), async (req, res) => {
  try {
    const challengeId = Number(req.params.id);
    if (!req.file) return res.status(400).json({ message: "photo file required" });

    const { caption } = req.body || {};
    const imageUrl = `/uploads/${req.file.filename}`;

    const photo = await prisma.photo.create({
      data: {
        challengeId,
        userId: req.user.id,
        imageUrl,
        caption: (caption ?? "").toString(),
      },
      include: { user: { select: { id: true, email: true } } },
    });

    res.json({
      id: photo.id,
      challengeId: photo.challengeId,
      imageUrl: photo.imageUrl,
      caption: photo.caption ?? "",
      userId: photo.user.id,
      userEmail: photo.user.email,
      createdAt: photo.createdAt.toISOString(),
      avgRating: 0,
      ratingCount: 0,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Failed to upload photo" });
  }
});

// get one photo
app.get("/photos/:id", async (req, res) => {
  try {
    const id = Number(req.params.id);
    const photo = await prisma.photo.findUnique({
      where: { id },
      include: {
        user: { select: { id: true, email: true } },
        ratings: { select: { value: true } },
      },
    });
    if (!photo) return res.status(404).json({ message: "Photo not found" });

    const ratingCount = photo.ratings.length;
    const avgRating =
      ratingCount === 0
        ? 0
        : photo.ratings.reduce((sum, r) => sum + r.value, 0) / ratingCount;

    res.json({
      id: photo.id,
      challengeId: photo.challengeId,
      imageUrl: photo.imageUrl,
      caption: photo.caption ?? "",
      userId: photo.user.id,
      userEmail: photo.user.email,
      createdAt: photo.createdAt.toISOString(),
      avgRating,
      ratingCount,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Failed to load photo" });
  }
});

// delete photo (only owner)
app.delete("/photos/:id", auth, async (req, res) => {
  try {
    const photoId = Number(req.params.id);

    const photo = await prisma.photo.findUnique({ where: { id: photoId } });
    if (!photo) return res.status(404).json({ message: "Photo not found" });

    if (photo.userId !== req.user.id) {
      return res.status(403).json({ message: "Not allowed" });
    }

    // delete file
    if (photo.imageUrl) {
      const filePath = path.join(__dirname, photo.imageUrl); // imageUrl starts with /uploads/...
      if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
    }

    await prisma.$transaction(async (tx) => {
    // 1) delete ratings for this photo
    await tx.rating.deleteMany({
      where: { photoId: photoId },
    });

    // 2) delete comments for this photo (if you have comments)
    await tx.comment.deleteMany({
      where: { photoId: photoId },
    });

    // 3) delete the photo
    await tx.photo.delete({
      where: { id: photoId },
    });
  });

    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Failed to delete photo" });
  }
});

// -------- COMMENTS --------
app.get("/photos/:id/comments", async (req, res) => {
  try {
    const photoId = Number(req.params.id);

    const comments = await prisma.comment.findMany({
      where: { photoId, parentId: null },
      orderBy: { createdAt: "asc" },
      include: {
        user: true,
        replies: {
          orderBy: { createdAt: "asc" },
          include: {
            user: true,
          },
        },
      },
    });


    res.json(
      comments.map((c) => ({
        id: c.id,
        text: c.text,
        photoId: c.photoId,
        userId: c.userId,
        user: {
          id: c.user.id,
          email: c.user.email,
          name: c.user.name,
          avatarUrl: c.user.avatarUrl,
        },
        createdAt: c.createdAt.toISOString(),
        replies: c.replies.map((r) => ({
          id: r.id,
          text: r.text,
          photoId: r.photoId,
          userId: r.userId,
          parentId: r.parentId,
          user: {
            id: r.user.id,
            email: r.user.email,
            name: r.user.name,
            avatarUrl: r.user.avatarUrl,
          },
          createdAt: r.createdAt.toISOString(),
        })),
      }))
    );
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Failed to load comments" });
  }
});


app.post("/photos/:id/comments", auth, async (req, res) => {
  try {
    const photoId = Number(req.params.id);
    const { text, parentId } = req.body;

    let finalParentId = null;

    if (parentId) {
      const parent = await prisma.comment.findUnique({
        where: { id: parentId },
        select: { parentId: true },
      });

      // 🔒 force 1-level nesting
      finalParentId = parent?.parentId ?? parentId;
    }

    const comment = await prisma.comment.create({
      data: {
        text,
        photoId,
        userId: req.user.id,
        parentId: finalParentId,
      },
      include: { user: true },
    });

    res.json(comment);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Failed to create comment" });
  }
});

// delete comment (only owner)
app.delete("/comments/:id", auth, async (req, res) => {
  try {
    const commentId = Number(req.params.id);

    const comment = await prisma.comment.findUnique({
      where: { id: commentId },
      select: { userId: true, photoId: true },
    });

    if (!comment) {
      return res.status(404).json({ message: "Comment not found" });
    }

    // 🔒 owner check
    if (comment.userId !== req.user.id) {
      return res.status(403).json({ message: "Not allowed" });
    }

    // delete replies first (1-level safe)
    await prisma.comment.deleteMany({
      where: { parentId: commentId },
    });

    await prisma.comment.delete({
      where: { id: commentId },
    });

    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Failed to delete comment" });
  }
});




// -------- RATINGS --------
// POST /photos/:id/ratings
app.post("/photos/:id/ratings", auth, async (req, res) => {
  const photoId = Number(req.params.id);
  const userId = req.user.id;
  const value = Number(req.body.value);

  // upsert rating
  await prisma.rating.upsert({
    where: {
      userId_photoId: {
        userId,
        photoId,
      },
    },
    update: { value },
    create: { value, userId, photoId },
  });

  // compute stats
  const stats = await prisma.rating.aggregate({
    where: { photoId },
    _avg: { value: true },
    _count: true,
  });

  res.json({
    photo: {
      id: photoId,
      avgRating: stats._avg.value ?? 0,
      ratingCount: stats._count,
    },
  });
});

//profile route
// --- USERS: public profile ---
app.get("/users/:id", async (req, res) => {
  try {
    const userId = Number(req.params.id);
    if (!Number.isFinite(userId)) {
      return res.status(400).json({ message: "Invalid user id" });
    }

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        name: true,
        avatarUrl: true,
        createdAt: true,
      },
    });

    if (!user) return res.status(404).json({ message: "User not found" });
    res.json(user);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Failed to load user" });
  }
});


// --- USERS: stats (photos count, avg rating, comments count, challenges count) ---
app.get("/users/:id/stats", auth, async (req, res) => {
  try {
    const userId = Number(req.params.id);
    if (!Number.isInteger(userId) || userId <= 0) {
      return res.status(400).json({ message: "Invalid user id" });
    }

    const photoCount = await prisma.photo.count({ where: { userId } });

    // challenge owner field: try creatorId then fallback to userId
    let challengeCount = 0;
    try {
      challengeCount = await prisma.challenge.count({ where: { creatorId: userId } });
    } catch (_) {
      challengeCount = await prisma.challenge.count({ where: { userId } });
    }

    // follow counts (if your model exists)
    let followersCount = 0;
    let followingCount = 0;
    try {
      followersCount = await prisma.follow.count({ where: { followingId: userId } });
      followingCount = await prisma.follow.count({ where: { followerId: userId } });
    } catch (_) {}

    // avg rating received (if your model exists)
    let avgRatingReceived = 0;
    let ratingCount = 0;
    try {
      const avgAgg = await prisma.photoRating.aggregate({
        where: { photo: { userId } },
        _avg: { value: true },
        _count: { value: true },
      });
      avgRatingReceived = avgAgg?._avg?.value ?? 0;
      ratingCount = avgAgg?._count?.value ?? 0;
    } catch (_) {}

    // isFollowing (optional)
    let isFollowing = false;
    try {
      const meId = req.user.id;
      const row = await prisma.follow.findFirst({
        where: { followerId: meId, followingId: userId },
        select: { id: true },
      });
      isFollowing = !!row;
    } catch (_) {}

    return res.json({
      photoCount,
      challengeCount,
      followersCount,
      followingCount,
      avgRatingReceived,
      ratingCount,
      isFollowing,
    });
  } catch (err) {
    console.error("GET /users/:id/stats failed:", err);
    return res.status(500).json({ message: "Failed to load stats" });
  }
});





// --- USERS: photos list (their submissions) ---
app.get("/users/:id/photos", async (req, res) => {
  try {
    const userId = Number(req.params.id);
    if (!Number.isFinite(userId)) {
      return res.status(400).json({ message: "Invalid user id" });
    }

    const photos = await prisma.photo.findMany({
      where: { userId },
      orderBy: { createdAt: "desc" },
      include: {
        challenge: { select: { id: true, title: true } },
        user: { select: { id: true, email: true, name: true, avatarUrl: true } },
        ratings: { select: { value: true } },
      },
    });

    res.json(
      photos.map((p) => {
        const count = p.ratings.length;
        const sum = p.ratings.reduce((acc, r) => acc + r.value, 0);
        const avg = count > 0 ? sum / count : 0;

        return {
          id: p.id,
          challengeId: p.challengeId,
          userId: p.userId,
          imageUrl: p.imageUrl,
          caption: p.caption,
          createdAt: p.createdAt.toISOString(),
          challenge: p.challenge,
          user: p.user,
          avgRating: avg,
          ratingCount: count,
        };
      })
    );
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Failed to load photos" });
  }
});



// --- USERS: challenges created by user ---
app.get("/users/:id/mychallenges", async (req, res) => {
  try {
    const userId = Number(req.params.id);
    if (!Number.isFinite(userId)) {
      req.url = `/users/${req.params.id}/mychallenges`;
       return app._router.handle(req, res, () => {});
    }

    const challenges = await prisma.challenge.findMany({
      where: { creatorId: userId },
      orderBy: { createdAt: "desc" },
      include: {
        creator: { select: { id: true, email: true, name: true, avatarUrl: true } },
        _count: { select: { photos: true } },
      },
    });

    res.json(
      challenges.map((c) => ({
        id: c.id,
        title: c.title,
        description: c.description,
        coverUrl: c.coverUrl,
        creatorId: c.creatorId,
        creator: c.creator,
        createdAt: c.createdAt.toISOString(),
        photoCount: c._count.photos,
      }))
    );
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Failed to load challenges" });
  }
});


// ✅ GET my profile
app.get("/me", auth, async (req, res) => {
  const me = await prisma.user.findUnique({ where: { id: req.user.id } });
  if (!me) return res.status(404).json({ message: "User not found" });
  res.json(publicUser(me));
});

// put my profile (edit name)
app.put("/me", auth, async (req, res) => {
  const { name } = req.body || {};
  const updated = await prisma.user.update({
    where: { id: req.user.id },
    data: { name: (name ?? "").toString().trim() || null },
  });
  res.json(publicUser(updated));
});

app.delete("/me", auth, async (req, res) => {
  try {
    const userId = req.user.id;

    await prisma.$transaction(async (tx) => {
      // 1) challenges created by me
      const myChallenges = await tx.challenge.findMany({
        where: { creatorId: userId },
        select: { id: true },
      });
      const myChallengeIds = myChallenges.map((c) => c.id);

      // 2) photos to delete:
      //    - my own photos
      //    - photos inside challenges I created (even if uploaded by others)
      const photosToDelete = await tx.photo.findMany({
        where: {
          OR: [
            { userId },
            ...(myChallengeIds.length > 0
              ? [{ challengeId: { in: myChallengeIds } }]
              : []),
          ],
        },
        select: { id: true },
      });
      const photoIds = photosToDelete.map((p) => p.id);

      // 3) delete ratings first (depend on photo/user)
      await tx.rating.deleteMany({
        where: {
          OR: [
            { userId },
            ...(photoIds.length > 0 ? [{ photoId: { in: photoIds } }] : []),
          ],
        },
      });

      // 4) delete comments on photos we will delete
      if (photoIds.length > 0) {
        await tx.comment.deleteMany({
          where: { photoId: { in: photoIds } },
        });
      }

      // 5) delete my comments elsewhere + any replies to them (recursive)
      await tx.$executeRaw`
        WITH RECURSIVE to_delete AS (
          SELECT "id" FROM "Comment" WHERE "userId" = ${userId}
          UNION ALL
          SELECT c."id"
          FROM "Comment" c
          JOIN to_delete td ON c."parentId" = td."id"
        )
        DELETE FROM "Comment"
        WHERE "id" IN (SELECT "id" FROM to_delete);
      `;

      // 6) delete photos
      if (photoIds.length > 0) {
        await tx.photo.deleteMany({ where: { id: { in: photoIds } } });
      }

      // 7) feed: remove my likes/comments, then my posts
      await tx.postLike.deleteMany({ where: { userId } });
      await tx.postComment.deleteMany({ where: { userId } });
      await tx.post.deleteMany({ where: { userId } }); // cascades delete comments/likes on my posts

      // 8) follow relations
      await tx.follow.deleteMany({
        where: { OR: [{ followerId: userId }, { followingId: userId }] },
      });

      // 9) delete my challenges (now safe because photos are removed)
      await tx.challenge.deleteMany({ where: { creatorId: userId } });

      // 10) finally delete user
      await tx.user.delete({ where: { id: userId } });
    });

    return res.json({ ok: true });
  } catch (e) {
    console.error("DELETE /me failed:", e);
    return res.status(500).json({ message: "Failed to delete account" });
  }
});



// ✅ POST avatar upload
app.post("/me/avatar", auth, upload.single("avatar"), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ message: "Missing avatar file" });

    const avatarPath = `/uploads/${req.file.filename}`; // matches your static /uploads setup
    const updated = await prisma.user.update({
      where: { id: req.user.id },
      data: { avatarUrl: avatarPath },
    });

    res.json(publicUser(updated));
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Failed to upload avatar" });
  }
});


// ✅ follow
app.post("/users/:id/follow", auth, async (req, res) => {
  const targetId = Number(req.params.id);
  if (!Number.isFinite(targetId)) return res.status(400).json({ message: "Invalid user id" });
  if (targetId === req.user.id) return res.status(400).json({ message: "You cannot follow yourself" });

  try {
    await prisma.follow.create({
      data: { followerId: req.user.id, followingId: targetId },
    });
    res.json({ success: true, following: true });
  } catch (e) {
    // already following -> treat as success
    res.json({ success: true, following: true });
  }
});

// ✅ unfollow
app.delete("/users/:id/follow", auth, async (req, res) => {
  const targetId = Number(req.params.id);
  if (!Number.isFinite(targetId)) return res.status(400).json({ message: "Invalid user id" });

  await prisma.follow.deleteMany({
    where: { followerId: req.user.id, followingId: targetId },
  });

  res.json({ success: true, following: false });
});

// ✅ followers list
app.get("/users/:id/followers", optionalAuth, async (req, res) => {
  const userId = Number(req.params.id);
  if (!Number.isFinite(userId)) return res.status(400).json({ message: "Invalid user id" });

  const rows = await prisma.follow.findMany({
    where: { followingId: userId },
    orderBy: { createdAt: "desc" },
    include: { follower: true },
  });

  res.json(rows.map(r => publicUser(r.follower)));
});

// ✅ following list
app.get("/users/:id/following", optionalAuth, async (req, res) => {
  const userId = Number(req.params.id);
  if (!Number.isFinite(userId)) return res.status(400).json({ message: "Invalid user id" });

  const rows = await prisma.follow.findMany({
    where: { followerId: userId },
    orderBy: { createdAt: "desc" },
    include: { following: true },
  });

  res.json(rows.map(r => publicUser(r.following)));
});

// alias for older frontend path
app.get("/users/:id/isFollowing", auth, async (req, res) => {
  const targetId = Number(req.params.id);
  if (!Number.isFinite(targetId)) return res.status(400).json({ message: "Invalid user id" });

  const found = await prisma.follow.findUnique({
    where: { followerId_followingId: { followerId: req.user.id, followingId: targetId } },
  });

  res.json({ isFollowing: !!found });
});

// =======================
// FEED (Posts / Comments / Likes)
// =======================

// GET feed posts (latest)
// optional auth -> if logged in, returns likedByMe
app.get("/posts", optionalAuth, async (req, res) => {
  try {
    const take = Math.min(Number(req.query.take || 20), 50);
    const cursor = req.query.cursor ? Number(req.query.cursor) : null;

    const posts = await prisma.post.findMany({
      take,
      ...(cursor ? { skip: 1, cursor: { id: cursor } } : {}),
      orderBy: { createdAt: "desc" },
      include: {
        user: true,
        _count: { select: { comments: true, likes: true } },
      },
    });

    let likedSet = new Set();
    if (req.user && posts.length) {
      const likes = await prisma.postLike.findMany({
        where: { userId: req.user.id, postId: { in: posts.map(p => p.id) } },
        select: { postId: true },
      });
      likedSet = new Set(likes.map(l => l.postId));
    }

    res.json(
      posts.map(p => ({
        id: p.id,
        text: p.text,
        imageUrl: p.imageUrl,
        createdAt: p.createdAt,
        user: publicUser(p.user),
        commentCount: p._count.comments,
        likeCount: p._count.likes,
        likedByMe: req.user ? likedSet.has(p.id) : false,
      }))
    );
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Failed to load posts" });
  }
});

// CREATE post (text + optional image upload)
app.post("/posts", auth, upload.single("image"), async (req, res) => {
  try {
    const text = (req.body.text || "").toString().trim();
    const imageUrl = req.file ? `/uploads/${req.file.filename}` : null;

    if (!text && !imageUrl) {
      return res.status(400).json({ message: "Post cannot be empty" });
    }

    const post = await prisma.post.create({
      data: {
        userId: req.user.id,
        text: text || null,
        imageUrl,
      },
      include: {
        user: true,
        _count: { select: { comments: true, likes: true } },
      },
    });

    res.json({
      id: post.id,
      text: post.text,
      imageUrl: post.imageUrl,
      createdAt: post.createdAt,
      user: publicUser(post.user),
      commentCount: post._count.comments,
      likeCount: post._count.likes,
      likedByMe: false,
    });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Failed to create post" });
  }
});

// DELETE post (owner)
app.delete("/posts/:id", auth, async (req, res) => {
  try {
    const postId = Number(req.params.id);
    if (!Number.isFinite(postId)) return res.status(400).json({ message: "Invalid post id" });

    const post = await prisma.post.findUnique({ where: { id: postId } });
    if (!post) return res.status(404).json({ message: "Post not found" });
    if (post.userId !== req.user.id) return res.status(403).json({ message: "Forbidden" });

    await prisma.post.delete({ where: { id: postId } });
    res.json({ success: true });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Failed to delete post" });
  }
});

// LIST comments for a post
app.get("/posts/:id/comments", optionalAuth, async (req, res) => {
  try {
    const postId = Number(req.params.id);
    if (!Number.isFinite(postId)) return res.status(400).json({ message: "Invalid post id" });

    const rows = await prisma.postComment.findMany({
      where: { postId },
      orderBy: { createdAt: "desc" },
      include: { user: true },
    });

    res.json(
      rows.map(c => ({
        id: c.id,
        text: c.text,
        createdAt: c.createdAt,
        user: publicUser(c.user),
      }))
    );
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Failed to load comments" });
  }
});

// ADD comment
app.post("/posts/:id/comments", auth, async (req, res) => {
  try {
    const postId = Number(req.params.id);
    if (!Number.isFinite(postId)) return res.status(400).json({ message: "Invalid post id" });

    const text = (req.body.text || "").toString().trim();
    if (!text) return res.status(400).json({ message: "Comment cannot be empty" });

    const c = await prisma.postComment.create({
      data: { postId, userId: req.user.id, text },
      include: { user: true },
    });

    res.json({
      id: c.id,
      text: c.text,
      createdAt: c.createdAt,
      user: publicUser(c.user),
    });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Failed to add comment" });
  }
});
// ✅ delete a post comment
app.delete("/posts/:postId/comments/:commentId", auth, async (req, res) => {
  const postId = Number(req.params.postId);
  const commentId = Number(req.params.commentId);

  if (!Number.isFinite(postId) || !Number.isFinite(commentId)) {
    return res.status(400).json({ message: "Invalid id" });
  }

  const c = await prisma.postComment.findUnique({
    where: { id: commentId },
    select: { id: true, postId: true, userId: true },
  });

  if (!c || c.postId !== postId) {
    return res.status(404).json({ message: "Comment not found" });
  }

  // allow: comment owner OR post owner
  const post = await prisma.post.findUnique({
    where: { id: postId },
    select: { userId: true },
  });

  const isOwner = c.userId === req.user.id;
  const isPostOwner = post?.userId === req.user.id;

  if (!isOwner && !isPostOwner) {
    return res.status(403).json({ message: "Not allowed" });
  }

  await prisma.postComment.delete({ where: { id: commentId } });
  res.json({ success: true });
});

// LIKE
app.post("/posts/:id/like", auth, async (req, res) => {
  try {
    const postId = Number(req.params.id);
    if (!Number.isFinite(postId)) return res.status(400).json({ message: "Invalid post id" });

    try {
      await prisma.postLike.create({ data: { postId, userId: req.user.id } });
    } catch (_) {
      // already liked -> ignore
    }
    res.json({ success: true, liked: true });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Failed to like" });
  }
});

// UNLIKE
app.delete("/posts/:id/like", auth, async (req, res) => {
  try {
    const postId = Number(req.params.id);
    if (!Number.isFinite(postId)) return res.status(400).json({ message: "Invalid post id" });

    await prisma.postLike.deleteMany({ where: { postId, userId: req.user.id } });
    res.json({ success: true, liked: false });
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Failed to unlike" });
  }
});

app.get("/me/stats", auth, async (req, res) => {
  try {
    const userId = req.user.id;

    const photoCount = await prisma.photo.count({ where: { userId } });

    // --- challengeCount: try creatorId first, fallback to userId ---
    let challengeCount = 0;
    try {
      challengeCount = await prisma.challenge.count({ where: { creatorId: userId } });
    } catch (_) {
      challengeCount = await prisma.challenge.count({ where: { userId } });
    }

    // --- followers / following: if Follow model exists, otherwise return 0 ---
    let followersCount = 0;
    let followingCount = 0;
    if (prisma.follow) {
      try {
        followersCount = await prisma.follow.count({ where: { followingId: userId } });
        followingCount = await prisma.follow.count({ where: { followerId: userId } });
      } catch (_) {
        // keep 0 if fields don't match
      }
    }

    // --- ratings: if PhotoRating model exists, otherwise return 0 ---
    let avgRatingReceived = 0;
    let ratingCount = 0;

    if (prisma.photoRating) {
      try {
        const avgAgg = await prisma.photoRating.aggregate({
          where: { photo: { userId } }, // relation name might differ in your schema
          _avg: { value: true },
          _count: { value: true },
        });

        avgRatingReceived = avgAgg?._avg?.value ?? 0;
        ratingCount = avgAgg?._count?.value ?? 0;
      } catch (_) {
        // keep 0 if relation/fields differ
      }
    }

    return res.json({
      photoCount,
      challengeCount,
      followersCount,
      followingCount,
      avgRatingReceived,
      ratingCount,
    });
  } catch (err) {
    console.error("GET /me/stats failed:", err);
    return res.status(500).json({ message: "Failed to load stats" });
  }
});

app.get("/me/photos", auth, async (req, res) => {
  try {
    const userId = req.user.id;

    const photos = await prisma.photo.findMany({
      where: { userId },
      orderBy: { createdAt: "desc" },
      include: {
        challenge: { select: { id: true, title: true } },
        user: { select: { id: true, email: true, name: true, avatarUrl: true } },
        ratings: { select: { value: true } },
      },
    });

    res.json(
      photos.map((p) => {
        const count = p.ratings.length;
        const sum = p.ratings.reduce((acc, r) => acc + r.value, 0);
        const avg = count > 0 ? sum / count : 0;

        return {
          id: p.id,
          challengeId: p.challengeId,
          userId: p.userId,
          imageUrl: p.imageUrl,
          caption: p.caption,
          createdAt: p.createdAt.toISOString(),
          challenge: p.challenge,
          user: p.user,
          avgRating: avg,
          ratingCount: count,
        };
      })
    );
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Failed to load my photos" });
  }
});

app.get("/me/challenges", auth, async (req, res) => {
  try {
    const userId = req.user.id;

    const challenges = await prisma.challenge.findMany({
      where: { creatorId: userId },
      orderBy: { createdAt: "desc" },
      include: {
        creator: { select: { id: true, email: true, name: true, avatarUrl: true } },
        _count: { select: { photos: true } },
      },
    });

    res.json(
      challenges.map((c) => ({
        id: c.id,
        title: c.title,
        description: c.description,
        coverUrl: c.coverUrl,
        creatorId: c.creatorId,
        creator: c.creator,
        createdAt: c.createdAt.toISOString(),
        photoCount: c._count.photos,
      }))
    );
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Failed to load my challenges" });
  }
});


// MY POSTS
app.get("/me/posts", auth, async (req, res) => {
  try {
    const authorId = req.user.id;   // whose posts we show
    const viewerId = req.user.id;   // who is viewing (me)

    const posts = await prisma.post.findMany({
      where: { userId: authorId }, // change to authorId if your schema uses that
      orderBy: { createdAt: "desc" },
      include: {
        user: { select: { id: true, name: true, email: true, avatarUrl: true } },
        _count: { select: { likes: true, comments: true } },
        likes: { where: { userId: viewerId }, select: { id: true } }, // ✅ for isLiked
      },
    });

    res.json(
      posts.map((p) => ({
        id: p.id,
        content: p.content,
        imageUrl: p.imageUrl,
        createdAt: p.createdAt,
        user: p.user,
        likeCount: p._count.likes,
        commentCount: p._count.comments,
        isLiked: p.likes.length > 0, // ✅
      }))
    );
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Failed to load posts" });
  }
});


app.get("/users/:id/posts", auth, async (req, res) => {
  try {
    const authorId = Number(req.params.id); // whose posts we show
    const viewerId = req.user.id;           // who is viewing (me)

    if (!Number.isInteger(authorId) || authorId <= 0) {
      return res.status(400).json({ message: "Invalid user id" });
    }

    const posts = await prisma.post.findMany({
      where: { userId: authorId }, // change to authorId if your schema uses that
      orderBy: { createdAt: "desc" },
      include: {
        user: { select: { id: true, name: true, email: true, avatarUrl: true } },
        _count: { select: { likes: true, comments: true } },
        likes: { where: { userId: viewerId }, select: { id: true } }, // ✅ for isLiked
      },
    });

    res.json(
      posts.map((p) => ({
        id: p.id,
        content: p.content,
        imageUrl: p.imageUrl,
        createdAt: p.createdAt,
        user: p.user,
        likeCount: p._count.likes,
        commentCount: p._count.comments,
        isLiked: p.likes.length > 0, // ✅
      }))
    );
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Failed to load posts" });
  }
});


// LIKED POSTS (ME)
app.get("/me/liked-posts", auth, async (req, res) => {
  try {
    const userId = req.user.id;

    const liked = await prisma.post.findMany({
      where: { likes: { some: { userId } } },
      orderBy: { createdAt: "desc" },
      include: {
        user: { select: { id: true, name: true, email: true, avatarUrl: true } },
        _count: { select: { likes: true, comments: true } },
      },
    });

    res.json(
      liked.map((p) => ({
        id: p.id,
        content: p.content,
        imageUrl: p.imageUrl,
        createdAt: p.createdAt,
        user: p.user,
        likeCount: p._count.likes,
        commentCount: p._count.comments,
        isLiked: true, // ✅ important
      }))
    );
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Failed to load liked posts" });
  }
});

// LIKED POSTS (OTHER USER)
app.get("/users/:id/liked-posts", auth, async (req, res) => {
  try {
    const userId = Number(req.params.id);
    if (!Number.isInteger(userId) || userId <= 0) {
      return res.status(400).json({ message: "Invalid user id" });
    }

    const liked = await prisma.post.findMany({
      where: { likes: { some: { userId } } },
      orderBy: { createdAt: "desc" },
      include: {
        user: { select: { id: true, name: true, email: true, avatarUrl: true } },
        _count: { select: { likes: true, comments: true } },
      },
    });

    res.json(
      liked.map((p) => ({
        id: p.id,
        content: p.content,
        imageUrl: p.imageUrl,
        createdAt: p.createdAt,
        user: p.user,
        likeCount: p._count.likes,
        commentCount: p._count.comments,
        isLiked: true, // ✅ important
      }))
    );
  } catch (e) {
    console.error(e);
    res.status(500).json({ message: "Failed to load liked posts" });
  }
});


// LESSONS
// LESSONS
app.get("/lessons", auth, async (req, res) => {
  const lessons = await prisma.lesson.findMany({ orderBy: { order: "asc" } });
  return res.json(lessons); //  list
});

app.get("/lessons/:id", auth, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id <= 0) {
    return res.status(400).json({ message: "Invalid lesson id" });
  }

  const lesson = await prisma.lesson.findUnique({ where: { id } });
  if (!lesson) return res.status(404).json({ message: "Lesson not found" });
  return res.json(lesson); //  map
});



async function seedDefaultLessons() {

  const lessons = [
    {
      slug: "camera-modes",
      title: "Camera Modes (Auto, P, A/Av, S/Tv, M)",
      order: 1,
      imageUrl: "https://picsum.photos/id/250/900/500",
      body: `Learn what each mode does and when to use it.

• Auto: camera decides everything (good for quick snapshots).
• P (Program): camera sets exposure, you can tweak ISO / exposure compensation.
• A/Av (Aperture Priority): you set aperture (background blur), camera sets shutter.
• S/Tv (Shutter Priority): you set shutter (motion), camera sets aperture.
• M (Manual): you set both shutter + aperture (full control).

Quick tips:
• Start with A/Av for portraits and general photography.
• Use S/Tv for action (sports, kids running, pets).
• Use M when light is tricky or you want consistency.

Practice:
1) Take the same scene in A/Av at f/2.8, f/5.6, f/11.
2) Try exposure compensation: -1, 0, +1 and compare.`,
    },
    {
      slug: "exposure-triangle",
      title: "Exposure Triangle: Aperture, Shutter, ISO",
      order: 2,
      imageUrl: "https://picsum.photos/id/251/900/500",
      body: `Exposure (brightness) comes from 3 settings:

1) Aperture (f-number)
• Controls light + background blur.
• Lower f-number = more light + more blur.

2) Shutter Speed
• Controls light + motion blur.
• Faster = freezes action. Slower = shows motion.

3) ISO
• Controls brightness by boosting sensor sensitivity.
• Higher ISO = brighter but more noise/grain.

Simple rules:
• Too dark? Open aperture OR slow shutter OR raise ISO.
• Motion blur? Use faster shutter (and raise ISO if needed).
• Too noisy? Lower ISO and compensate with aperture/shutter.

Practice:
Take the same indoor photo using:
• ISO 200 (may blur)
• ISO 800
• ISO 1600
Compare noise vs sharpness.`,
    },
    {
      slug: "aperture-bokeh",
      title: "Aperture & Background Blur (Depth of Field)",
      order: 3,
      imageUrl: "https://picsum.photos/id/10/900/500",
      body: `Aperture affects BOTH light and depth of field (how much is in focus).

Common ranges:
• f/1.8 – f/2.8: strong background blur (portraits)
• f/4 – f/5.6: balanced blur + sharpness (everyday)
• f/8 – f/11: more in focus (landscapes)

What changes blur?
• Lower f-number = blurrier background.
• Closer subject = blurrier background.
• Farther background = blurrier background.
• Longer focal length = blurrier background.

Practice:
Take 3 portraits at:
• f/2.0, f/4.0, f/8.0
Keep distance similar and compare the background.`,
    },
    {
      slug: "shutter-speed-motion",
      title: "Shutter Speed & Motion (Freeze vs Blur)",
      order: 4,
      imageUrl: "https://picsum.photos/id/253/900/500",
      body: `Shutter speed controls how motion looks.

Typical shutter speeds:
• 1/1000 – 1/2000: sports, birds, fast action
• 1/500: running / jumping
• 1/250: walking people
• 1/125: casual handheld
• 1/60 and slower: risk of handshake blur
• 1–10 seconds: night / light trails (tripod)

Creative technique: Panning
• Use 1/30–1/60 and move your camera with the subject.
• Subject stays sharper, background blurs.

Practice:
1) Take a moving subject at 1/1000 (freeze).
2) Try panning at 1/30 and see the motion effect.`,
    },
    {
      slug: "iso-noise",
      title: "ISO & Noise (How to keep photos clean)",
      order: 5,
      imageUrl: "https://picsum.photos/id/254/900/500",
      body: `ISO brightens your photo but adds noise/grain.

Good starting points:
• Bright daylight: ISO 100–200
• Cloudy / shade: ISO 200–800
• Indoor: ISO 800–1600
• Night: ISO 1600–6400 (depends on camera)

Important:
• A sharp noisy photo is better than a blurry clean photo.
• Don’t be afraid of ISO—just avoid going higher than needed.

Tip:
Enable Auto ISO with a maximum:
• Mid phones/cameras: max ISO 1600–3200
• Better cameras: max ISO 6400+

Practice:
Take the same scene at ISO 100, 800, 3200 and zoom in to compare noise.`,
    },
    {
      slug: "autofocus-modes",
      title: "Autofocus Modes (AF-S, AF-C) + Focus Areas",
      order: 6,
      imageUrl: "https://picsum.photos/id/20/900/500",
      body: `Getting focus right makes your photos look professional.

Focus modes:
• AF-S (Single): best for still subjects (people posing, objects).
• AF-C (Continuous): best for moving subjects (sports, pets, kids).
• Face/Eye AF: best for portraits (keeps eyes sharp).

Focus area types:
• Single point: most accurate
• Zone: good for moving subjects
• Wide/Auto: fast, less precise

Practice:
1) Use AF-S + single point on a still object.
2) Use AF-C + zone on someone walking toward you.
Check which is sharper.`,
    },
    {
      slug: "composition-rule-of-thirds",
      title: "Composition Basics (Rule of Thirds, Leading Lines)",
      order: 7,
      imageUrl: "https://picsum.photos/id/30/900/500",
      body: `Composition is how you arrange elements in the frame.

Fast improvements:
• Rule of thirds: place subject on 1/3 lines (use grid).
• Leading lines: roads/rails/walls guide the eye.
• Framing: windows/doors/arches frame your subject.
• Clean background: avoid distractions behind the subject.
• Symmetry: great for architecture and reflections.

Practice:
Take 10 photos:
• 5 centered
• 5 rule-of-thirds
Compare which looks more interesting.`,
    },
    {
      slug: "white-balance-color",
      title: "White Balance & Color (Fix yellow/blue photos)",
      order: 8,
      imageUrl: "https://picsum.photos/id/257/900/500",
      body: `White balance controls the color temperature of your photo.

Common problems:
• Indoor lights look too yellow/orange.
• Shade looks too blue.

Options:
• Auto WB: usually ok
• Daylight / Cloudy / Tungsten: quick fixes
• Kelvin (K): manual control

Simple Kelvin guide:
• Daylight: ~5500K
• Cloudy: ~6500K
• Tungsten indoor: ~3200K–4500K

Practice:
Shoot indoors:
• Auto WB
• Tungsten WB
See which has more natural colors.`,
    },
    {
      slug: "metering-exposure-comp",
      title: "Metering & Exposure Compensation (+/-)",
      order: 9,
      imageUrl: "https://picsum.photos/id/40/900/500",
      body: `Sometimes the camera “guesses” wrong brightness.

Use exposure compensation (EV):
• Bright background (sky) → subject too dark → try +0.7 to +1.3 EV
• Dark scene → camera brightens too much → try -0.7 EV

Metering modes:
• Matrix/Evaluative: general use
• Spot: expose for one specific area (face, bright object)

Practice:
Photograph a person with bright sky behind:
• 0 EV
• +1 EV
Compare the face brightness.`,
    },
    {
      slug: "raw-vs-jpeg-editing",
      title: "RAW vs JPEG + Basic Editing",
      order: 10,
      imageUrl: "https://picsum.photos/id/259/900/500",
      body: `JPEG:
• Smaller files
• Ready to share
• Less editing flexibility

RAW:
• Larger files
• Best for editing (recover highlights/shadows)
• Better color control

Simple editing order:
1) Exposure
2) Highlights / Shadows
3) White balance
4) Contrast
5) Crop / straighten

Tip:
Avoid over-saturation and over-sharpening—natural looks better.`,
    },
    {
      slug: "lenses-focal-length",
      title: "Lens & Focal Length Basics (What to use when)",
      order: 11,
      imageUrl: "https://picsum.photos/id/50/900/500",
      body: `Focal length changes perspective and framing.

Common focal lengths:
• 14–24mm: wide landscapes / architecture
• 35mm: street / everyday
• 50mm: natural perspective
• 85mm: portraits (nice compression)
• 100–200mm: sports / wildlife

Tip for portraits:
Use 50mm–85mm and step back a bit for more flattering faces.

Practice:
Take the same subject using wide vs zoom (or 1x vs 3x).
Notice how background and face proportions change.`,
    },
    {
      slug: "night-photography",
      title: "Night Photography (Handheld vs Tripod)",
      order: 12,
      imageUrl: "https://picsum.photos/id/261/900/500",
      body: `Night photos need more light, so you must choose a strategy.

Handheld night:
• Aperture: as wide as possible (f/1.8–2.8)
• Shutter: 1/60 or faster (avoid shake)
• ISO: 1600–3200+

Tripod night:
• ISO: 100–400
• Shutter: 1–10 seconds
• Aperture: f/4–f/8
• Use timer to avoid camera shake

Practice:
Shoot a street scene handheld and then on a tripod.
Compare sharpness and noise.`,
    },
  ];


  await prisma.lesson.createMany({
  data: lessons,
  skipDuplicates: true, 
  });

  console.log("✅ Seeded default lessons");
}

// mail
const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: Number(process.env.SMTP_PORT || 587),
  secure: false,
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
  // helps avoid ::1 / IPv6 weirdness in some environments
  family: 4,
  // optional safety
  connectionTimeout: 10_000,
  greetingTimeout: 10_000,
  socketTimeout: 10_000,
});


console.log("SMTP_HOST:", process.env.SMTP_HOST);
console.log("SMTP_PORT:", process.env.SMTP_PORT);


async function sendVerificationEmail(email, code) {
  const from = process.env.SMTP_FROM || process.env.SMTP_USER;
  await transporter.sendMail({
    from,
    to: email,
    subject: "Your FotoFocus verification code",
    text: `Your verification code is: ${code}\n\nThis code expires in 10 minutes.`,
  });
}




// -------- start --------
app.listen(PORT, "0.0.0.0", () => {
  console.log(`✅ API running on http://0.0.0.0:${PORT}`);
});
// Seed default lessons
if (process.env.SEED_ON_BOOT === "true") {
  await seedDefaultLessons();
}

// Health check
app.get("/health", (req, res) => res.json({ ok: true }));




