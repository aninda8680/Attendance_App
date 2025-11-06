require('dotenv').config();
const express = require('express');
const puppeteer = require('puppeteer');
const CryptoJS = require('crypto-js');
const cors = require('cors');
const { MongoClient } = require('mongodb');

const app = express();

// ====== MIDDLEWARE ======
app.use(cors());
app.use(express.json());

// ====== CONFIG ======
const ENC_KEY = process.env.ENC_KEY || 'dev_secret_key_change_this';
const mongoUri = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/attendance_app';
let usersCollection;

const LOGIN_URL = 'https://adamasknowledgecity.ac.in/student/login';
const ATT_URL = 'https://adamasknowledgecity.ac.in/student/attendance';

let browser; // Persistent browser

// ====== MONGO INIT ======
async function initDB() {
  try {
    const client = new MongoClient(mongoUri);
    await client.connect();
    const db = client.db('attendance_app');
    usersCollection = db.collection('users');
    console.log('✅ MongoDB connected');
  } catch (err) {
    console.error('❌ MongoDB connection failed:', err);
  }
}
initDB();

// ====== PERSISTENT BROWSER ======
async function getBrowser() {
  if (!browser) {
    try {
      browser = await puppeteer.launch({
        headless: true,
        args: [
          '--no-sandbox',
          '--disable-setuid-sandbox',
          '--disable-dev-shm-usage',
          '--disable-gpu',
          '--single-process',
        ],
      });
      console.log('🚀 Puppeteer browser launched');
    } catch (e) {
      console.error('❌ Puppeteer launch failed:', e);
    }
  }
  return browser;
}

// ====== ROUTES ======

// Health Check
app.get('/', (req, res) => res.send('attendance-proto backend running ✅'));

// Save Credentials
app.post('/save-credentials', async (req, res) => {
  try {
    const { uid, username, password } = req.body;
    if (!uid) return res.status(400).json({ error: 'missing_uid' });
    if (!username) return res.status(400).json({ error: 'missing_username' });
    if (!password) return res.status(400).json({ error: 'missing_password' });

    const cipher = CryptoJS.AES.encrypt(
      JSON.stringify({ username, password }),
      ENC_KEY
    ).toString();

    await usersCollection.updateOne(
      { uid },
      { $set: { username, password: cipher } },
      { upsert: true }
    );

    console.log(`✅ Saved credentials for UID: ${uid}`);
    res.json({ ok: true });
  } catch (err) {
    console.error('❌ Error in /save-credentials:', err);
    res.status(500).json({ error: 'server_error', message: err.message });
  }
});

// Clear Credentials
app.post('/clear-credentials', async (req, res) => {
  const { uid } = req.body || {};
  if (!uid) return res.status(400).json({ error: 'missing_uid' });

  await usersCollection.deleteOne({ uid });
  console.log(`🗑️ Cleared credentials for UID: ${uid}`);
  res.json({ ok: true });
});

// Fetch Attendance
app.get('/fetch-attendance', async (req, res) => {
  const { uid } = req.query;
  if (!uid) return res.status(400).json({ error: 'missing_uid' });

  const user = await usersCollection.findOne({ uid });
  if (!user) return res.status(400).json({ error: 'no_credentials' });

  const bytes = CryptoJS.AES.decrypt(user.password, ENC_KEY);
  const creds = JSON.parse(bytes.toString(CryptoJS.enc.Utf8));
  const { username, password } = creds;

  let page;
  try {
    const browser = await getBrowser();
    page = await browser.newPage();
    await page.setViewport({ width: 1200, height: 900 });

    // Restore cookies if present
    if (user.cookies?.length) {
      const validCookies = user.cookies
        .filter(c => c.name && c.value && c.domain)
        .map(c => ({
          name: c.name,
          value: c.value,
          domain: c.domain,
          path: c.path || '/',
          httpOnly: c.httpOnly || false,
          secure: c.secure || false,
          sameSite: c.sameSite || 'Lax',
        }));
      if (validCookies.length) {
        console.log(`🔑 Restoring ${validCookies.length} cookies`);
        await page.setCookie(...validCookies);
      }
    }

    // Go to attendance page first
    await page.goto(ATT_URL, { waitUntil: 'domcontentloaded', timeout: 20000 });

    // Login if redirected
    if (page.url().includes('login')) {
      console.log('📄 Logging in...');
      await page.goto(LOGIN_URL, { waitUntil: 'domcontentloaded', timeout: 20000 });
      await page.type('input[name="registration_no"]', username, { delay: 50 });
      await page.type('input[name="password"]', password, { delay: 50 });

      await Promise.all([
        page.click('#login_btn'),
        page.waitForNavigation({ waitUntil: 'domcontentloaded', timeout: 15000 }),
      ]);

      const newCookies = await page.cookies();
      await usersCollection.updateOne({ uid }, { $set: { cookies: newCookies } });
    }

    // Fetch attendance table
    await page.goto(ATT_URL, { waitUntil: 'domcontentloaded', timeout: 15000 });
    const attendance = await page.evaluate(() => {
      const table = document.querySelector('#myTable');
      if (!table) return { error: 'no_table_found', html: document.body.innerHTML.slice(0, 500) };

      const rows = Array.from(table.querySelectorAll('tbody tr'));
      return rows.map(r => {
        const cols = r.querySelectorAll('td');
        return {
          course: cols[0]?.innerText.trim() || '',
          totalClasses: cols[1]?.innerText.trim() || '',
          totalPresent: cols[2]?.innerText.trim() || '',
          totalAbsent: cols[3]?.innerText.trim() || '',
          percentage: cols[4]?.innerText.trim() || '',
        };
      });
    });

    if (attendance.error) {
      console.error('❌ Attendance table not found. Partial HTML:', attendance.html);
      throw new Error('attendance_table_not_found');
    }

    await page.close();
    res.json({ ok: true, attendance });
  } catch (err) {
    if (page) await page.close();
    console.error('❌ Fetch error:', err);
    res.status(500).json({ error: 'scrape_failed', message: err.message });
  }
});

// ====== SERVER ======
const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => console.log(`🚀 Listening on port ${PORT}`));
