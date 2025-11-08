import express from "express";
import axios from "axios";
import * as cheerio from "cheerio";
import { CookieJar } from "tough-cookie";
import { wrapper } from "axios-cookiejar-support";

const app = express();
app.use(express.json());

const BASE_URL = "https://adamasknowledgecity.ac.in";

// ✅ Optional root message
app.get("/", (req, res) => {
  res.send("✅ Adamas Attendance API is live. Use POST /attendance");
});

app.post("/attendance", async (req, res) => {
  const { username, password } = req.body;

  if (!username || !password) {
    return res.status(400).json({ error: "Username and password required" });
  }

  try {
    // 🍪 Create axios client with cookie support
    const jar = new CookieJar();
    const client = wrapper(axios.create({ jar, withCredentials: true }));

    // STEP 1️⃣: Get login page and extract CSRF token
    const loginPage = await client.get(`${BASE_URL}/student/login`);
    const $ = cheerio.load(loginPage.data);
    const csrfToken = $('input[name="_token"]').val();

    if (!csrfToken) {
      console.error("❌ No CSRF token found");
      return res.status(500).json({ error: "CSRF token not found" });
    }

    // STEP 2️⃣: Log in using correct field names
    const loginResponse = await client.post(
      `${BASE_URL}/student/login`,
      new URLSearchParams({
        _token: csrfToken,
        registration_no: username, // ✅ correct field name
        password: password,
      }),
      {
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
        maxRedirects: 0,
        validateStatus: (status) => status < 500,
      }
    );

    if (loginResponse.status !== 302) {
      console.log("❌ Login failed. Status:", loginResponse.status);
      return res.status(401).json({ error: "Invalid username or password" });
    }

    // STEP 3️⃣: Request attendance page
    const attendancePage = await client.get(`${BASE_URL}/student/attendance`);
    const $$ = cheerio.load(attendancePage.data);

    const attendanceData = [];

    // ✅ Correct selector for attendance table
    $$('#myTable tbody tr').each((i, row) => {
      const cols = $$(row).find('td');
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
      console.log("⚠️ No rows found in #myTable");
      return res.status(200).json({
        success: true,
        attendance: [],
        message: "No attendance data found — possibly invalid session.",
      });
    }

    // ✅ Success response
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

// ✅ Use Render's dynamic port
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log("✅ Server running on port", PORT));
