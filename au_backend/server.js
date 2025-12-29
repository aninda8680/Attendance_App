import express from "express";
import axios from "axios";
import * as cheerio from "cheerio";
import { CookieJar } from "tough-cookie";
import { wrapper } from "axios-cookiejar-support";
import admin from "./firebase.js";
import crypto from "crypto";


const app = express();
// 🔐 Temporary in-memory FCM token store
const userFcmTokens = new Map();
// ⚠️ Temporary in-memory password store (for background polling)
const userPasswords = new Map();
// 🔸 Firestore reference
const firestore = admin.firestore();

// 🔁 Store last attendance snapshot
const lastAttendanceMap = new Map();


app.use(express.json());

const BASE_URL = "https://adamasknowledgecity.ac.in";
// -------------------- AES-256-GCM helpers --------------------
function getAesKey() {
  const keyB64 = process.env.AES_KEY || "";

  console.log("🔐 AES_KEY present:", Boolean(keyB64));
  console.log("🔐 AES_KEY (base64) length:", keyB64.length);

  const key = Buffer.from(keyB64, "base64");

  console.log("🔐 AES_KEY decoded byte length:", key.length);

  if (key.length !== 32) {
    throw new Error("AES_KEY must be 32 bytes base64 (256-bit)");
  }

  return key;
}


function encryptPassword(plain) {
  const key = getAesKey();
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", key, iv);
  const enc = Buffer.concat([cipher.update(plain, "utf8"), cipher.final()]);
  const tag = cipher.getAuthTag();
  return {
    iv: iv.toString("base64"),
    ct: enc.toString("base64"),
    tag: tag.toString("base64"),
  };
}

function decryptPassword(encObj) {
  const key = getAesKey();
  const iv = Buffer.from(encObj.iv, "base64");
  const ct = Buffer.from(encObj.ct, "base64");
  const tag = Buffer.from(encObj.tag, "base64");
  const decipher = crypto.createDecipheriv("aes-256-gcm", key, iv);
  decipher.setAuthTag(tag);
  const dec = Buffer.concat([decipher.update(ct), decipher.final()]);
  return dec.toString("utf8");
}




async function sendAttendancePush(username, status, subject) {
  let token = userFcmTokens.get(username);
  if (!token) {
    // Fallback: read from Firestore so notifications work after server restarts
    try {
      const userDoc = await firestore.collection("users").doc(username).get();
      if (userDoc.exists) {
        const data = userDoc.data() || {};
        token = data.fcmToken;
        if (token) {
          // cache for subsequent sends this runtime
          userFcmTokens.set(username, token);
        }
      }
    } catch (e) {
      console.warn("⚠️ Failed to fetch FCM token from Firestore for", username, e);
    }
  }

  if (!token) {
    console.log("⚠️ No FCM token for:", username);
    return;
  }

  const statusText = status === "P" ? "Present" : "Absent";

  const message = {
    token,
    notification: {
      title: "AU Attendance",
      body: `${statusText} in ${subject}`,
    },
    data: {
      type: "attendance",
      subject,
      status: status, // 'P' or 'A'
    },
    android: {
      priority: "high",
      notification: {
        clickAction: "FLUTTER_NOTIFICATION_CLICK",
      },
    },
  };

  try {
    const res = await admin.messaging().send(message);
    console.log("✅ Attendance push sent:", res);
  } catch (err) {
    console.error("❌ Push failed:", err.message);
  }
}



// 🔔 Send attendance push notification
async function sendAttendanceNotification(fcmToken, attendance, subject) {
  const message = {
    token: fcmToken,
    notification: {
      title: attendance === "P" ? "PRESENT" : "ABSENT",
      body: `in ${subject}`,
    },
    android: {
      priority: "high",
    },
  };

  try {
    await admin.messaging().send(message);
    console.log("🔔 Push sent:", attendance, subject);
  } catch (err) {
    console.error("❌ Push failed:", err.message);
  }
}











app.get("/", (req, res) => {
  res.send("✅ Adamas Attendance API is live. Use POST /attendance");
});






app.post("/save-fcm-token", (req, res) => {
  const { username, fcmToken } = req.body;

  console.log("📩 /save-fcm-token:", req.body);

  if (!username || !fcmToken) {
    return res.status(400).json({
      success: false,
      message: "username and fcmToken required",
    });
  }

  // Save / update token
  userFcmTokens.set(username, fcmToken);

  console.log("✅ FCM token saved for:", username);

  // Also persist to Firestore (merge)
  firestore
    .collection("users")
    .doc(username)
    .set({ fcmToken, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true })
    .catch((e) => console.error("⚠️ Firestore save fcmToken failed:", e));

  return res.status(200).json({
    success: true,
  });
});




// ✅ Register user for background notifications (temporary in-memory storage)
// Body: { username, password, fcmToken }
app.post("/register-user", async (req, res) => {
  const contentType = req.headers["content-type"] || "";
  const { username, password, fcmToken } = req.body || {};

  // Validate payload
  if (!username || !password || !fcmToken) {
    return res.status(400).json({
      success: false,
      message: "username, password, fcmToken required",
      hint: "Send JSON with fields { username, password, fcmToken } and header Content-Type: application/json",
      receivedContentType: contentType,
    });
  }

  // Verify AES key before attempting encryption
  try {
    getAesKey();
  } catch (keyErr) {
    console.error("❌ AES_KEY invalid or missing:", keyErr.message);
    return res.status(500).json({
      success: false,
      message: "Server encryption key (AES_KEY) invalid or missing. Contact admin.",
      details: "AES_KEY must be a base64-encoded 32-byte value (256-bit)",
    });
  }

  // In-memory (for current runtime)
  userPasswords.set(username, password);
  userFcmTokens.set(username, fcmToken);

  // Persist to Firestore with AES encryption
  try {
    const encPassword = encryptPassword(password);
    await firestore
      .collection("users")
      .doc(username)
      .set(
        {
          fcmToken,
          encPassword,
          failureCount: 0,
          nextPollAt: new Date(Date.now() + Math.floor(POLL_INTERVAL_MS * (0.5 + Math.random()))),
          lastPoll: null,
          lastNotify: null,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    console.log("✅ Registered for background polling:", username);
    return res.status(200).json({ success: true });
  } catch (e) {
    const msg = e && e.message ? e.message : String(e);
    console.error("❌ register-user failed:", msg);
    return res.status(500).json({ success: false, message: "Registration failed", error: msg });
  }
});













app.post("/attendance", async (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) {
    return res.status(400).json({ error: "Username and password required" });
  }

  try {
    // 🍪 Prepare cookie jar & axios client
    const jar = new CookieJar();
    const client = wrapper(axios.create({ jar, withCredentials: true }));

    // STEP 1️⃣: GET login page → extract CSRF token
    const loginPage = await client.get(`${BASE_URL}/student/login`, {
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/122 Safari/537.36",
      },
    });

    const $ = cheerio.load(loginPage.data);
    const csrfToken = $('input[name="_token"]').val();

    if (!csrfToken) {
      console.error("❌ CSRF token not found");
      return res.status(500).json({ error: "CSRF token not found" });
    }

    // STEP 2️⃣: Send login POST with correct fields
    const formData = new URLSearchParams({
      _token: csrfToken,
      registration_no: username,
      password: password,
      login: "login", // ✅ required button value for Laravel form
    });

    const loginResponse = await client.post(
      `${BASE_URL}/student/login`,
      formData.toString(),
      {
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "Referer": `${BASE_URL}/student/login`,
          "Origin": BASE_URL,
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/122 Safari/537.36",
        },
        maxRedirects: 0,
        validateStatus: (s) => s < 500,
      }
    );

    console.log("🔍 Login status:", loginResponse.status);

    if (loginResponse.status !== 302) {
      console.log("❌ Login failed. Probably invalid credentials or CSRF.");
      return res.status(401).json({ error: "Invalid username or password" });
    }

    // STEP 3️⃣: Fetch attendance page
    const attendancePage = await client.get(`${BASE_URL}/student/attendance`, {
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/122 Safari/537.36",
        "Referer": `${BASE_URL}/student/dashboard`,
      },
    });

    const $$ = cheerio.load(attendancePage.data);
    const attendanceData = [];

    // ✅ Parse attendance table (#myTable)
    $$('#myTable tbody tr').each((i, row) => {
      const cols = $$(row).find("td");
      if (cols.length >= 5) {
        attendanceData.push({
          subject: $$(cols[0]).text().trim(),
          total_classes: $$(cols[1]).text().trim(),
          total_present: $$(cols[2]).text().trim(),
          total_absent: $$(cols[3]).text().trim(),
          percent: $$(cols[4]).text().trim(),
        });
      }
    });

    if (attendanceData.length === 0) {
      console.log("⚠️ No rows found in #myTable – possible login redirect.");
      return res.status(200).json({
        success: true,
        attendance: [],
        message: "No attendance data found — possibly invalid session.",
      });
    }

    res.json({
      success: true,
      attendance: attendanceData,
      total_subjects: attendanceData.length,
    });
  } catch (err) {
    console.error("❌ Error fetching attendance:", err);
    res.status(500).json({ error: "Something went wrong" });
  }
});















app.post("/routine", async (req, res) => {
  const { username, password, date } = req.body;

  if (!username || !password || !date) {
    return res.status(400).json({ error: "username, password, date required" });
  }

  // Log the incoming payload to debug differences between Postman and app
  console.log("📥 /routine payload:", {
    username,
    passwordMasked: password ? `${"*".repeat(Math.min(4, password.length))} (len:${password.length})` : null,
    rawDate: date,
  });

  // helper: normalize date strings to dd-MM-yyyy (always two digits)
  function normalizeDateString(s) {
    if (!s || typeof s !== "string") return s;
    const m = s.match(/(\d{1,2})-(\d{1,2})-(\d{4})/);
    if (!m) return s;
    const d = String(m[1]).padStart(2, "0");
    const mo = String(m[2]).padStart(2, "0");
    const y = m[3];
    return `${d}-${mo}-${y}`;
  }

  try {
    console.log("\n==============================");
    console.log("📅 Requesting routine for:", date);
    console.log("==============================\n");

    const jar = new CookieJar();
    const client = wrapper(axios.create({ jar, withCredentials: true }));

    // STEP 1: Login (get CSRF)
    const loginPage = await client.get(`${BASE_URL}/student/login`);
    const $login = cheerio.load(loginPage.data);
    const csrfToken = $login('input[name="_token"]').val();

    const formData = new URLSearchParams({
      _token: csrfToken,
      registration_no: username,
      password: password,
      login: "login",
    });

    const loginResponse = await client.post(
      `${BASE_URL}/student/login`,
      formData.toString(),
      { maxRedirects: 0, validateStatus: s => s < 500 }
    );

    if (loginResponse.status !== 302) {
      console.log("❌ Login failed (status:", loginResponse.status, ")");
      return res.status(401).json({ error: "Invalid login" });
    }

    // STEP 2: Fetch routine page
    const routinePage = await client.get(`${BASE_URL}/student/routine?pre=${date}`);
    const $ = cheerio.load(routinePage.data);

    // collect available dates on the page (normalize them)
    const foundDates = [];
    $("td.week-day").each((i, el) => {
      const txt = $(el).text();
      const m = txt.match(/(\d{1,2}-\d{1,2}-\d{4})/);
      if (m) {
        const raw = m[1].trim();
        const norm = normalizeDateString(raw);
        foundDates.push({
          dayName: txt.split("\n")[0].trim(),
          dayDate: norm,
          rawDate: raw,
        });
      }
    });

    console.log("🔍 Checking <td.week-day> rows:");
    $("td.week-day").each((i, el) => {
      console.log("   → CELL:", $(el).text().trim());
    });

    // normalize incoming requested date for matching
    const requestedNorm = normalizeDateString(date);

    // STEP 3: Correct date matching using normalized extraction
    const dayRow = $("td.week-day")
      .filter((i, el) => {
        const txt = $(el).text();
        const match = txt.match(/(\d{1,2}-\d{1,2}-\d{4})/);
        if (!match) return false;
        const cellDateRaw = match[1].trim();
        const cellDate = normalizeDateString(cellDateRaw);
        console.log("🔎 Found cell date:", cellDate, "| Matching:", requestedNorm);
        return cellDate === requestedNorm;
      })
      .closest("tr");

    if (!dayRow.length) {
      console.log("❌ No matching date row found on website. Returning availableDates:", foundDates);
      return res.json({
        success: false,
        dayName: "",
        dayDate: requestedNorm,
        periods: [],
        availableDates: foundDates,
        message: "No routine found for selected date",
      });
    }

    console.log("✅ Matched row found!");

    // Extract dayName + dayDate (normalize the dayDate too)
    const weekText = dayRow.find("td.week-day").text().trim();
    const dateMatch = weekText.match(/(\d{1,2}-\d{1,2}-\d{4})/);
    const rawDayDate = dateMatch ? dateMatch[1] : date;
    const dayDate = normalizeDateString(rawDayDate);
    const dayName = weekText.split("\n")[0].trim();

    // STEP 4: Parse periods
    const periods = [];
    let periodCounter = 1;

    dayRow.find("td.routine-content").each((i, col) => {
      const $col = $(col);

      const span = parseInt($col.attr("colspan") || "1");
      const subject = $col.find(".class-subject").text().trim();
      const teacher = $col.find(".class-teacher").text().trim();
      const room = $col.find(".bulding-room").text().trim();

      let attendance = "";
      if ($col.find(".attendance_status_present").length) attendance = "P";
      else if ($col.find(".attendance_status_absent").length) attendance = "A";

      for (let s = 0; s < span; s++) {
        periods.push({
          period: periodCounter,
          subject,
          teacher,
          attendance,
          room
        });
        periodCounter++;
      }
    });

    console.log("📘 Parsed periods:", periods.length);

  

// 🔔 ATTENDANCE UPDATE DETECTION (BLANK→A/P, A↔P)
const previous = lastAttendanceMap.get(username) || {};

for (const p of periods) {
  if (!p.subject || !p.attendance) continue;

  const key = `${dayDate}_${p.subject}`;
  const oldStatus = previous[key];      // undefined, A, or P
  const newStatus = p.attendance;       // A or P

  // ✅ Notify on ANY meaningful change
  if (oldStatus !== newStatus) {
    console.log("🔔 Attendance update:", {
      subject: p.subject,
      from: oldStatus ?? "BLANK",
      to: newStatus,
    });

    await sendAttendancePush(
      username,
      newStatus,
      p.subject
    );
  }

  // Save latest state
  previous[key] = newStatus;
}

lastAttendanceMap.set(username, previous);



    // Always produce 8 periods
    while (periods.length < 8) {
      periods.push({
        period: periods.length + 1,
        subject: "",
        teacher: "",
        attendance: "",
        room: ""
      });
    }

    return res.json({
      success: true,
      dayName,
      dayDate,
      periods,
    });

  } catch (err) {
    console.error("❌ Routine fetch failed:", err);
    res.status(500).json({ error: "Routine fetch failed" });
  }
});

// 🔄 BACKGROUND POLLING — checks routine for today and sends push on change
function _formatDateDDMMYYYY(dt) {
  const d = String(dt.getDate()).padStart(2, "0");
  const m = String(dt.getMonth() + 1).padStart(2, "0");
  const y = String(dt.getFullYear());
  return `${d}-${m}-${y}`;
}

async function pollUserRoutineAndNotify(username) {
  try {
    // Load user from Firestore
    const userDoc = await firestore.collection("users").doc(username).get();
    if (!userDoc.exists) {
      return false;
    }
    const userData = userDoc.data();
    const fcmToken = userData?.fcmToken;
    const encPassword = userData?.encPassword;
    if (!fcmToken || !encPassword) {
      return false;
    }
    const password = decryptPassword(encPassword);

    const jar = new CookieJar();
    const client = wrapper(axios.create({ jar, withCredentials: true }));

    // Login
    const loginPage = await client.get(`${BASE_URL}/student/login`);
    const $login = cheerio.load(loginPage.data);
    const csrfToken = $login('input[name="_token"]').val();

    const formData = new URLSearchParams({
      _token: csrfToken,
      registration_no: username,
      password: password,
      login: "login",
    });

    const loginResponse = await client.post(
      `${BASE_URL}/student/login`,
      formData.toString(),
      { maxRedirects: 0, validateStatus: s => s < 500 }
    );

    if (loginResponse.status !== 302) {
      console.log("❌ Background login failed for:", username);
      return false;
    }

    // Fetch routine for today
    const today = _formatDateDDMMYYYY(new Date());
    const routinePage = await client.get(`${BASE_URL}/student/routine?pre=${today}`);
    const $ = cheerio.load(routinePage.data);

    // Extract dayName/dayDate
    function normalizeDateString(s) {
      if (!s || typeof s !== "string") return s;
      const m = s.match(/(\d{1,2})-(\d{1,2})-(\d{4})/);
      if (!m) return s;
      const d = String(m[1]).padStart(2, "0");
      const mo = String(m[2]).padStart(2, "0");
      const y = m[3];
      return `${d}-${mo}-${y}`;
    }

    const requestedNorm = normalizeDateString(today);
    const dayRow = $("td.week-day")
      .filter((i, el) => {
        const txt = $(el).text();
        const match = txt.match(/(\d{1,2}-\d{1,2}-\d{4})/);
        if (!match) return false;
        const cellDateRaw = match[1].trim();
        const cellDate = normalizeDateString(cellDateRaw);
        return cellDate === requestedNorm;
      })
      .closest("tr");

    if (!dayRow.length) {
      // No routine (holiday/day off)
      return true; // Consider as successful poll with nothing to notify
    }

    const weekText = dayRow.find("td.week-day").text().trim();
    const dateMatch = weekText.match(/(\d{1,2}-\d{1,2}-\d{4})/);
    const rawDayDate = dateMatch ? dateMatch[1] : requestedNorm;
    const dayDate = normalizeDateString(rawDayDate);

    // Parse periods
    const periods = [];
    let periodCounter = 1;
    dayRow.find("td.routine-content").each((i, col) => {
      const $col = $(col);
      const span = parseInt($col.attr("colspan") || "1");
      const subject = $col.find(".class-subject").text().trim();
      const teacher = $col.find(".class-teacher").text().trim();
      const room = $col.find(".bulding-room").text().trim();
      let attendance = "";
      if ($col.find(".attendance_status_present").length) attendance = "P";
      else if ($col.find(".attendance_status_absent").length) attendance = "A";
      for (let s = 0; s < span; s++) {
        periods.push({ period: periodCounter, subject, teacher, attendance, room });
        periodCounter++;
      }
    });

    // Detect and notify (hydrate previous from Firestore snapshots)
    const previous = lastAttendanceMap.get(username) || {};
    const snapsQuery = await firestore
      .collection("snapshots")
      .where("username", "==", username)
      .where("dayDate", "==", dayDate)
      .get();
    const snapMap = new Map();
    snapsQuery.forEach((doc) => {
      const d = doc.data();
      snapMap.set(d.subject, d.status);
    });

    let notified = false;
    let notifiedSubject = "";
    for (const p of periods) {
      if (!p.subject || !p.attendance) continue;
      const key = `${dayDate}_${p.subject}`;
      let oldStatus = previous[key];
      if (oldStatus === undefined) {
        oldStatus = snapMap.get(p.subject);
      }
      const newStatus = p.attendance;
      if (oldStatus !== newStatus) {
        await sendAttendancePush(username, newStatus, p.subject);
        notified = true;
        notifiedSubject = p.subject;
      }
      previous[key] = newStatus;
      // Persist snapshot
      await firestore
        .collection("snapshots")
        .doc(`${username}__${dayDate}__${p.subject}`)
        .set(
          {
            username,
            dayDate,
            subject: p.subject,
            status: newStatus,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
    }
    lastAttendanceMap.set(username, previous);

    // Update user lastPoll/lastNotify
    const update = { lastPoll: admin.firestore.FieldValue.serverTimestamp() };
    if (notified) {
      update.lastNotify = admin.firestore.FieldValue.serverTimestamp();
      update.lastNotifySubject = notifiedSubject;
    }
    await firestore.collection("users").doc(username).set(update, { merge: true });
    return true;
  } catch (err) {
    console.error("❌ Background poll error for", username, err);
    return false;
  }
}

// Configurable polling interval (defaults to 30s)
const POLL_INTERVAL_MS = Number(process.env.POLL_INTERVAL_MS || 30000);
const POLL_JITTER_PCT = Number(process.env.POLL_JITTER_PCT || 0.3); // ±30% jitter
const POLL_BACKOFF_MAX_MS = Number(process.env.POLL_BACKOFF_MAX_MS || 15 * 60 * 1000); // 15 minutes cap
console.log("⏱️ Polling interval (ms):", POLL_INTERVAL_MS, "jitter:", POLL_JITTER_PCT, "backoffMax:", POLL_BACKOFF_MAX_MS);

function _computeNextPoll(nowMs, baseMs, failureCount) {
  // On success, baseMs = POLL_INTERVAL_MS; On failure, baseMs = backoff delay
  const jitterRange = baseMs * POLL_JITTER_PCT;
  const jitter = (Math.random() * 2 - 1) * jitterRange; // [-range, +range]
  return nowMs + baseMs + Math.max(-jitterRange, Math.min(jitter, jitterRange));
}

setInterval(async () => {
  try {
    const usersSnap = await firestore.collection("users").get();
    const nowMs = Date.now();
    for (const doc of usersSnap.docs) {
      const username = doc.id;
      const u = doc.data() || {};
      const failureCount = Number(u.failureCount || 0);
      let nextPollAtMs = 0;
      if (u.nextPollAt) {
        // Firestore Timestamp → ms
        try {
          nextPollAtMs = typeof u.nextPollAt.toMillis === "function" ? u.nextPollAt.toMillis() : Date.parse(u.nextPollAt);
        } catch {
          nextPollAtMs = 0;
        }
      }

      // Initialize nextPollAt with jitter if missing
      if (!nextPollAtMs) {
        const initNext = _computeNextPoll(nowMs, POLL_INTERVAL_MS, 0);
        await firestore.collection("users").doc(username).set({ nextPollAt: new Date(initNext), failureCount: 0 }, { merge: true });
        continue;
      }

      // Skip until it's time
      if (nowMs < nextPollAtMs) continue;

      // It's time to poll this user
      const ok = await pollUserRoutineAndNotify(username);
      if (ok) {
        const nextMs = _computeNextPoll(nowMs, POLL_INTERVAL_MS, 0);
        await firestore.collection("users").doc(username).set({ nextPollAt: new Date(nextMs), failureCount: 0 }, { merge: true });
      } else {
        const backoffMs = Math.min(POLL_INTERVAL_MS * Math.pow(2, failureCount + 1), POLL_BACKOFF_MAX_MS);
        const nextMs = _computeNextPoll(nowMs, backoffMs, failureCount + 1);
        await firestore.collection("users").doc(username).set({ nextPollAt: new Date(nextMs), failureCount: failureCount + 1 }, { merge: true });
      }
    }
  } catch (e) {
    console.error("❌ Poll scheduler error:", e);
  }
}, POLL_INTERVAL_MS);






// 🩺 Health endpoint
app.get("/health", async (req, res) => {
  try {
    const usersSnap = await firestore.collection("users").get();
    const users = usersSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
    res.json({
      status: "ok",
      serverTime: new Date().toISOString(),
      userCount: users.length,
      users: users.map((u) => ({
        username: u.id,
        lastPoll: u.lastPoll ?? null,
        lastNotify: u.lastNotify ?? null,
        lastNotifySubject: u.lastNotifySubject ?? null,
        failureCount: typeof u.failureCount === "number" ? u.failureCount : 0,
        nextPollAt: u.nextPollAt
          ? (typeof u.nextPollAt.toDate === "function" ? u.nextPollAt.toDate().toISOString() : new Date(u.nextPollAt).toISOString())
          : null,
        fcmTokenPresent: !!u.fcmToken,
      })),
    });
  } catch (e) {
    res.status(500).json({ status: "error", message: String(e) });
  }
});





// 🔧 Quick config diagnostics
app.get("/config-check", (req, res) => {
  let aesOk = false;
  let aesError = null;
  try {
    getAesKey();
    aesOk = true;
  } catch (e) {
    aesOk = false;
    aesError = e && e.message ? e.message : String(e);
  }
  const fbOk = !!admin && !!admin.app;
  res.json({
    status: "ok",
    aesKeyValid: aesOk,
    aesError,
    firebaseInitialized: fbOk,
  });
});






// 🧪 Simulation endpoint (does NOT hit university site)
// Guarded by env SIMULATION_TOKEN; triggers a notification and persists snapshots
// Body: { username, subject, status: 'P'|'A', date?: 'dd-MM-yyyy' }
app.post("/simulate-notification", async (req, res) => {
  const token = req.headers["x-sim-token"] || req.body?.token || "";
  const expected = process.env.SIMULATION_TOKEN || "";
  if (!expected || token !== expected) {
    return res.status(403).json({ success: false, message: "Forbidden" });
  }

  const { username, subject, status, date } = req.body || {};
  if (!username || !subject || !status) {
    return res.status(400).json({ success: false, message: "username, subject, status required" });
  }
  const s = String(status).toUpperCase();
  if (s !== "P" && s !== "A") {
    return res.status(400).json({ success: false, message: "status must be 'P' or 'A'" });
  }
  const dayDate = date && typeof date === "string" ? date : _formatDateDDMMYYYY(new Date());

  try {
    // Send push
    await sendAttendancePush(username, s, subject);

    // Persist snapshot for consistency
    await firestore
      .collection("snapshots")
      .doc(`${username}__${dayDate}__${subject}`)
      .set(
        {
          username,
          dayDate,
          subject,
          status: s,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

    // Update in-memory cache so subsequent real polls compare correctly
    const prev = lastAttendanceMap.get(username) || {};
    prev[`${dayDate}_${subject}`] = s;
    lastAttendanceMap.set(username, prev);

    // Update user notify metadata
    await firestore
      .collection("users")
      .doc(username)
      .set(
        {
          lastNotify: admin.firestore.FieldValue.serverTimestamp(),
          lastNotifySubject: subject,
        },
        { merge: true }
      );

    return res.json({ success: true, message: "Notification simulated", username, subject, status: s, dayDate });
  } catch (e) {
    return res.status(500).json({ success: false, message: "Simulation failed", error: String(e) });
  }
});


















const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log("✅ Server running on port", PORT));