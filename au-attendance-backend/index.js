require("dotenv").config();
const express = require("express");
const cors = require("cors");
const puppeteer = require("puppeteer");
const CryptoJS = require("crypto-js");
const { MongoClient } = require("mongodb");

const app = express();
app.use(cors());
app.use(express.json());

// ====== CONFIG ======
const ENC_KEY = process.env.ENC_KEY;
const MONGO_URI = process.env.MONGO_URI;
const PORT = process.env.PORT || 3000;

if (!MONGO_URI || !ENC_KEY) {
  console.error("❌ Missing environment variables! Check .env file.");
  process.exit(1);
}

// ====== DATABASE CONNECTION ======
let db;
async function connectDB() {
  try {
    const client = new MongoClient(MONGO_URI, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
      ssl: true,
    });
    await client.connect();
    db = client.db("attendance");
    console.log("✅ Connected to MongoDB Atlas");
  } catch (err) {
    console.error("❌ MongoDB connection error:", err);
    process.exit(1);
  }
}
connectDB();

// ====== ENCRYPTION HELPERS ======
function encrypt(text) {
  return CryptoJS.AES.encrypt(text, ENC_KEY).toString();
}
function decrypt(ciphertext) {
  try {
    const bytes = CryptoJS.AES.decrypt(ciphertext, ENC_KEY);
    return bytes.toString(CryptoJS.enc.Utf8);
  } catch {
    return "";
  }
}

// ====== ROUTES ======
app.get("/", (req, res) => res.send("✅ Attendance backend is running!"));

// Save credentials
app.post("/save-credentials", async (req, res) => {
  try {
    const { uid, username, password } = req.body;
    if (!uid || !username || !password)
      return res.status(400).json({ error: "Missing credentials" });

    const encrypted = {
      uid,
      username: encrypt(username),
      password: encrypt(password),
      createdAt: new Date(),
    };

    await db.collection("credentials").updateOne({ uid }, { $set: encrypted }, { upsert: true });
    res.json({ success: true, message: "Credentials saved securely!" });
  } catch (err) {
    console.error("Error saving creds:", err);
    res.status(500).json({ error: "Server error" });
  }
});

// Fetch attendance
app.get("/fetch-attendance", async (req, res) => {
  try {
    const { uid } = req.query;
    if (!uid) return res.status(400).json({ error: "Missing uid" });

    const creds = await db.collection("credentials").findOne({ uid });
    if (!creds) return res.status(404).json({ error: "Credentials not found" });

    const username = decrypt(creds.username);
    const password = decrypt(creds.password);

    console.log("Navigating to attendance page...");
    const browser = await puppeteer.launch({
      headless: "new",
      args: ["--no-sandbox", "--disable-setuid-sandbox"],
    });

    const page = await browser.newPage();
    await page.goto("https://auadms.adamasuniversity.ac.in/", {
      waitUntil: "domcontentloaded",
    });

    console.log("Current URL:", page.url());

    // TODO: update selectors as per actual portal
    await page.type("#username", username);
    await page.type("#password", password);
    await Promise.all([
      page.click("#loginBtn"),
      page.waitForNavigation({ waitUntil: "networkidle2" }),
    ]);

    // Example extraction
    const attendance = await page.evaluate(() => {
      const rows = document.querySelectorAll(".attendance-row");
      return Array.from(rows).map((row) => ({
        course: row.querySelector(".subject")?.textContent?.trim() || "",
        totalPresent: row.querySelector(".present")?.textContent?.trim() || "",
        totalClasses: row.querySelector(".total")?.textContent?.trim() || "",
        percentage: row.querySelector(".percent")?.textContent?.trim() || "",
      }));
    });

    await browser.close();
    res.json({ success: true, attendance });
  } catch (err) {
    console.error("Error in fetch-attendance:", err);
    res.status(500).json({ error: "Attendance fetch failed" });
  }
});

// Clear credentials
app.post("/clear-credentials", async (req, res) => {
  try {
    const { uid } = req.body;
    if (!uid) return res.status(400).json({ error: "Missing uid" });

    await db.collection("credentials").deleteOne({ uid });
    res.json({ success: true, message: "Credentials cleared" });
  } catch (err) {
    console.error("Error clearing creds:", err);
    res.status(500).json({ error: "Server error" });
  }
});

// ====== START SERVER ======
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
});
