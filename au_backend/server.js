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

  try {
    console.log("🔵 Starting login flow for:", username);

    const jar = new CookieJar();
    const client = wrapper(axios.create({ jar, withCredentials: true }));

    // Step 1: Load login page
    console.log("🔵 Fetching login page...");
    const loginPage = await client.get(`${BASE_URL}/student/login`);

    console.log("✅ Login page status:", loginPage.status);
    console.log("✅ Cookies after GET:", jar.toJSON());

    const $ = cheerio.load(loginPage.data);
    const csrfToken = $('input[name="_token"]').val();

    console.log("✅ Extracted CSRF:", csrfToken);

    if (!csrfToken) {
      console.log("❌ CSRF missing. Page dump:");
      console.log(loginPage.data.substring(0, 500));
      return res.status(500).json({ error: "CSRF token extraction failed" });
    }

    // Step 2: Login
    console.log("🔵 Sending login POST...");
    const formData = new URLSearchParams({
      _token: csrfToken,
      registration_no: username,
      password: password,
      login: "login",
    });

    const loginResponse = await client.post(
      `${BASE_URL}/student/login`,
      formData.toString(),
      {
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          Referer: `${BASE_URL}/student/login`,
        },
        maxRedirects: 0,
        validateStatus: () => true
      }
    );

    console.log("✅ Login response status:", loginResponse.status);
    console.log("✅ Cookies after login:", jar.toJSON());

    if (loginResponse.status !== 302) {
      console.log("❌ Login failed. Body snippet:");
      console.log(loginResponse.data.substring(0, 300));
      return res.status(401).json({
        error: "Login failed — incorrect credentials OR form changed."
      });
    }

    // Step 3: Attendance page
    console.log("🔵 Fetching attendance page...");
    const attendancePage = await client.get(`${BASE_URL}/student/attendance`);

    console.log("✅ Attendance page status:", attendancePage.status);

    const $$ = cheerio.load(attendancePage.data);
    const rows = $$("#myTable tbody tr");

    console.log("✅ Rows found:", rows.length);

    const attendanceData = [];
    rows.each((i, r) => {
      const c = $$(r).find("td");
      attendanceData.push({
        subject: $$(c[0]).text().trim(),
        total_classes: $$(c[1]).text().trim(),
        total_present: $$(c[2]).text().trim(),
        total_absent: $$(c[3]).text().trim(),
        percent: $$(c[4]).text().trim()
      });
    });

    return res.json({ success: true, attendance: attendanceData });

  } catch (e) {
    console.log("❌ FULL ERROR:");
    console.log(e);
    return res.status(500).json({ error: "Server crashed — check logs" });
  }
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log("✅ Server running on port", PORT));
