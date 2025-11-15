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

  try {
    const jar = new CookieJar();
    const client = wrapper(axios.create({ jar, withCredentials: true }));

    // 1) LOGIN PAGE → CSRF
    const loginPage = await client.get(`${BASE_URL}/student/login`);
    const $ = cheerio.load(loginPage.data);
    const csrfToken = $('input[name="_token"]').val();
    if (!csrfToken) return res.status(500).json({ error: "CSRF missing" });

    // 2) LOGIN POST
    const loginResponse = await client.post(
      `${BASE_URL}/student/login`,
      new URLSearchParams({
        _token: csrfToken,
        registration_no: username,
        password,
        login: "login",
      }).toString(),
      { maxRedirects: 0, validateStatus: (s) => s < 500 }
    );

    if (loginResponse.status !== 302) {
      return res.status(401).json({ error: "Invalid username or password" });
    }

    // 3) Convert date
    const formatted = date.split("-").reverse().join("-");
    const [dd, mm] = formatted.split("-");

    // 4) LOAD routine FORM PAGE → new CSRF token
    const routineFormPage = await client.get(`${BASE_URL}/student/routine`);
    const $$ = cheerio.load(routineFormPage.data);
    const routineToken = $$('input[name="_token"]').val();

    // -------- AUTO-DETECT WEEK --------
    const found = {
      rowHtml: null,
      pageHtml: null,
    };

    for (let w = 1; w <= 5; w++) {
      const resp = await client.post(
        `${BASE_URL}/student/routine`,
        new URLSearchParams({
          _token: routineToken,
          month: mm,
          week: w.toString(),
          date: formatted,
          search: "search",
        }).toString()
      );

      const $$$ = cheerio.load(resp.data);

      $$$(".table.table-bordered tbody tr").each((_, row) => {
        const weekText = $$$(".week-day", row).text().replace(/\s+/g, " ").trim();
        const match = weekText.match(/\d{2}-\d{2}-\d{4}/);

        if (match && match[0] === formatted) {
          found.rowHtml = $$$.html(row);
          found.pageHtml = resp.data;
        }
      });

      if (found.rowHtml) break;
    }

    // No routine for this date
    if (!found.rowHtml) {
      return res.json({
        selected: date,
        dayName: new Date(date).toLocaleDateString("en-US", { weekday: "long" }),
        dayDate: date,
        periods: [],
      });
    }

    // -------- PARSE PERIODS --------
    const pageParser = cheerio.load(found.pageHtml);
    const rowParser = cheerio.load(found.rowHtml);

    const periods = [];
    let periodIndex = 1;

    rowParser("td.routine-content").each((_, cell) => {
      const c = rowParser(cell);

      const colspan = parseInt(c.attr("colspan") || "1");
      const subject = c.find(".class-subject").text().trim() || "-";
      const teacher = c.find(".class-teacher").text().trim() || "-";
      const room = c.find(".bulding-room").text().trim() || "-";

      let attendance = "-";
      if (c.find(".attendance_status_present").length) attendance = "P";
      if (c.find(".attendance_status_absent").length) attendance = "A";

      for (let i = 0; i < colspan; i++) {
        periods.push({
          subject,
          teacher,
          room,
          attendance,
          periodIndex,
          colspan,
        });
        periodIndex++;
      }
    });

    // -------- RESPONSE --------
    return res.json({
      selected: date,
      dayName: new Date(date).toLocaleDateString("en-US", { weekday: "long" }),
      dayDate: date,
      periods,
    });

  } catch (err) {
    console.error("❌ Routine Error:", err);
    return res.status(500).json({ error: "Failed routine fetch" });
  }
});
app.post("/routine", async (req, res) => {
  const { username, password, date } = req.body;

  if (!username || !password || !date) {
    return res.status(400).json({ error: "username, password, date required" });
  }

  try {
    const jar = new CookieJar();
    const client = wrapper(axios.create({ jar, withCredentials: true }));

    // 1️⃣ Load login page → CSRF
    const loginPage = await client.get(`${BASE_URL}/student/login`);
    const $ = cheerio.load(loginPage.data);
    const csrfToken = $('input[name="_token"]').val();
    if (!csrfToken) return res.status(500).json({ error: "CSRF missing" });

    // 2️⃣ POST login
    const formData = new URLSearchParams({
      _token: csrfToken,
      registration_no: username,
      password,
      login: "login"
    });

    const loginResponse = await client.post(
      `${BASE_URL}/student/login`,
      formData.toString(),
      {
        maxRedirects: 0,
        validateStatus: s => s < 500
      }
    );

    if (loginResponse.status !== 302)
      return res.status(401).json({ error: "Invalid username or password" });

    // 3️⃣ Load routine page
    const routinePage = await client.get(`${BASE_URL}/student/routine`);
    const $$ = cheerio.load(routinePage.data);

    // ⚠ Convert yyyy-mm-dd → dd-mm-yyyy (matches website)
    const formatted = date.split("-").reverse().join("-");

    // 4️⃣ Find the row with matching date inside <td class="week-day">
    let targetRow = null;

    $$('.table.table-bordered tbody tr').each((_, row) => {
      const text = $$(row).find('.week-day').text();
      if (text.includes(formatted)) {
        targetRow = row;
      }
    });

    if (!targetRow) {
      return res.json({
        selected: date,
        dayName: new Date(date).toLocaleDateString("en-US", { weekday: "long" }),
        dayDate: date,
        periods: []
      });
    }

    const periods = [];
    let periodIndex = 1;

    // 5️⃣ Extract cells for that day (skip first <td.week-day>)
    const cells = $$(targetRow).find("td.routine-content");

    cells.each((_, cell) => {
      const colspanAttr = $$(cell).attr("colspan");
      const colspan = colspanAttr ? parseInt(colspanAttr) : 1;

      const subject = $$(cell).find(".class-subject").text().trim() || "-";
      const teacher = $$(cell).find(".class-teacher").text().trim() || "-";
      const room = $$(cell).find(".bulding-room").text().trim() || "-";

      let attendance = "-";
      if ($$(cell).find(".attendance_status_present").length) attendance = "P";
      if ($$(cell).find(".attendance_status_absent").length) attendance = "A";

      // Push multiple periods if colspan > 1
      for (let i = 0; i < colspan; i++) {
        periods.push({
          subject,
          teacher,
          room,
          attendance,
          periodIndex,
          colspan
        });
        periodIndex++;
      }
    });

    // 6️⃣ Respond exactly in Flutter model structure
    return res.json({
      selected: date,
      dayName: new Date(date).toLocaleDateString("en-US", { weekday: "long" }),
      dayDate: date,
      periods
    });

  } catch (err) {
    console.error("❌ Routine Error:", err);
    return res.status(500).json({ error: "Something went wrong fetching routine" });
  }
});







const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log("✅ Server running on port", PORT));