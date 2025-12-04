import express from "express";
import axios from "axios";
import * as cheerio from "cheerio";
import { CookieJar } from "tough-cookie";
import { wrapper } from "axios-cookiejar-support";

const app = express();
app.use(express.json());

const BASE_URL = "https://adamasknowledgecity.ac.in";










app.get("/", (req, res) => {
  res.send("✅ Adamas Attendance API is live. Use POST /attendance");
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


















const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log("✅ Server running on port", PORT));