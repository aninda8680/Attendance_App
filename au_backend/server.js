import express from "express";
import axios from "axios";
import * as cheerio from "cheerio";
import { CookieJar } from "tough-cookie";
import { wrapper } from "axios-cookiejar-support";

const app = express();
app.use(express.json());

const BASE_URL = "https://adamasknowledgecity.ac.in";

app.post("/attendance", async (req, res) => {
  const { username, password } = req.body;

  if (!username || !password) {
    return res.status(400).json({ error: "Username and password required" });
  }

  try {
    // Prepare cookie jar
    const jar = new CookieJar();
    const client = wrapper(axios.create({ jar, withCredentials: true }));

    // STEP 1: GET LOGIN PAGE → extract CSRF TOKEN
    const loginPage = await client.get(`${BASE_URL}/student/login`);
    const $ = cheerio.load(loginPage.data);
    const csrfToken = $('input[name="_token"]').val();

    if (!csrfToken) {
      return res.status(500).json({ error: "CSRF token not found" });
    }

    // STEP 2: SEND LOGIN POST
    const loginResponse = await client.post(
      `${BASE_URL}/student/login`,
      {
        _token: csrfToken,
        email: username,
        password: password,
      },
      {
        headers: {
          "Content-Type": "application/json",
        },
        maxRedirects: 0, // We want to manually follow
        validateStatus: (s) => s < 500,
      }
    );

    // Login failed?
    if (loginResponse.status !== 302) {
      return res.status(401).json({ error: "Invalid username or password" });
    }

    // STEP 3: Access attendance page
    const att = await client.get(`${BASE_URL}/student/attendance`);
    const $$ = cheerio.load(att.data);

    let attendance = [];

    $$("#DataTables_Table_0 tbody tr").each((i, row) => {
      const cols = $$(row).find("td");

      attendance.push({
        subject: $$(cols[1]).text().trim(),
        held: $$(cols[2]).text().trim(),
        attended: $$(cols[3]).text().trim(),
        percent: $$(cols[4]).text().trim(),
      });
    });

    return res.json({ success: true, attendance });

  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Something went wrong" });
  }
});

app.listen(5000, () => console.log("Server running on port 5000"));
