import express from "express";
import axios from "axios";
import * as cheerio from "cheerio";
import { CookieJar } from "tough-cookie";
import { wrapper } from "axios-cookiejar-support";

const app = express();
app.use(express.json());

const BASE_URL = "https://adamasknowledgecity.ac.in";

// Optional: show a friendly message when visiting root
app.get("/", (req, res) => {
  res.send("✅ Attendance backend is live. Use POST /attendance");
});

app.post("/attendance", async (req, res) => {
  const { username, password } = req.body;

  if (!username || !password) {
    return res.status(400).json({ error: "Username and password required" });
  }

  try {
    // STEP 1: Prepare cookie jar & axios client
    const jar = new CookieJar();
    const client = wrapper(axios.create({ jar, withCredentials: true }));

    // STEP 2: Fetch login page to extract CSRF token
    const loginPage = await client.get(`${BASE_URL}/student/login`);
    const $ = cheerio.load(loginPage.data);
    const csrfToken = $('input[name="_token"]').val();

    if (!csrfToken) {
      console.error("❌ CSRF token missing");
      return res.status(500).json({ error: "CSRF token not found" });
    }

    // STEP 3: Send correct form fields (Laravel expects urlencoded)
    const loginResponse = await client.post(
      `${BASE_URL}/student/login`,
      new URLSearchParams({
        _token: csrfToken,
        registration_no: username,   // ✅ correct key
        password: password,          // ✅ correct key
      }),
      {
        headers: {
          "Content-Type": "application/x-www-form-urlencoded", // ✅ Laravel expects this
        },
        maxRedirects: 0,
        validateStatus: (s) => s < 500,
      }
    );

    // STEP 4: Check login result
    if (loginResponse.status !== 302) {
      console.log("❌ Login failed, status:", loginResponse.status);
      return res.status(401).json({ error: "Invalid username or password" });
    }

    // STEP 5: Access attendance page
    const attendancePage = await client.get(`${BASE_URL}/student/attendance`);
    const $$ = cheerio.load(attendancePage.data);
    const attendance = [];

    $$('#DataTables_Table_0 tbody tr').each((i, row) => {
      const cols = $$(row).find("td");
      attendance.push({
        subject: $$(cols[1]).text().trim(),
        held: $$(cols[2]).text().trim(),
        attended: $$(cols[3]).text().trim(),
        percent: $$(cols[4]).text().trim(),
      });
    });

    if (attendance.length === 0) {
      return res.status(200).json({
        success: true,
        attendance: [],
        message: "No attendance data found (maybe session timeout?)",
      });
    }

    return res.json({ success: true, attendance });
  } catch (err) {
    console.error("❌ Error:", err);
    return res.status(500).json({ error: "Something went wrong" });
  }
});

// Use dynamic Render port
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log("✅ Server running on port", PORT));
