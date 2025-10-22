/* eslint-disable no-unused-vars */
/* eslint-disable object-curly-spacing */
/* eslint-disable max-len */

const {onSchedule} = require("firebase-functions/v2/scheduler");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// === YARDIMCI FONKSİYON: Haftanın başlangıcı (Pazartesi 00:00) ===
function getStartOfWeek(date) {
  const d = new Date(date);
  const day = d.getDay();
  const diff = d.getDate() - day + (day === 0 ? -6 : 1);
  const startOfWeek = new Date(d.setDate(diff));
  startOfWeek.setHours(0, 0, 0, 0);
  return startOfWeek;
}

/**
 * MEVCUT HAFTALIK Liderlik Tablosunu Hesaplar.
 * Her 10 dakikada bir çalışır.
 */
exports.calculateCurrentWeeklyLeaderboard = onSchedule({
  schedule: "*/10 * * * *",
  timeZone: "Europe/Istanbul",
}, async (event) => {
  logger.info("MEVCUT HAFTALIK liderlik hesaplaması başlıyor (10dk)...");

  const now = new Date();
  const startOfThisWeek = getStartOfWeek(now);
  logger.info(`Hesaplanan Hafta Aralığı: ${startOfThisWeek.toISOString()} - ${now.toISOString()}`);

  const solvedQuizzesRef = db
      .collectionGroup("solvedQuizzes")
      .where("tarih", ">=", startOfThisWeek);
  const snapshot = await solvedQuizzesRef.get();

  const weeklyScores = new Map();
  snapshot.forEach((doc) => {
    const data = doc.data();
    const puan = data.puan || 0;
    const userId = doc.ref.parent.parent.id;
    const currentScore = weeklyScores.get(userId) || 0;
    weeklyScores.set(userId, currentScore + puan);
  });
  logger.info(`Toplam ${weeklyScores.size} kullanıcının puanı hesaplandı.`);

  const batch = db.batch();
  const leaderboardRef = db.collection("mevcutHaftalikLiderlik");

  const oldEntries = await leaderboardRef.get();
  oldEntries.forEach((doc) => batch.delete(doc.ref));

  for (const [userId, puan] of weeklyScores.entries()) {
    const userDoc = await db.collection("users").doc(userId).get();
    let kullaniciAdi = "İsimsiz Kullanıcı";
    let emoji = "🙂"; // Varsayılan emoji

    if (userDoc.exists) {
      const userData = userDoc.data();
      // --- DÜZELTME: 'kullaniciAdi' alma mantığı ---
      if (userData && userData.kullaniciAdi) {
        kullaniciAdi = userData.kullaniciAdi;
      } else if (userData && userData.email) {
        kullaniciAdi = userData.email;
      }
      // --- DÜZELTME: 'emoji' alma mantığı (?. kaldırıldı) ---
      if (userData && userData.emoji) {
        emoji = userData.emoji;
      }
    }

    batch.set(leaderboardRef.doc(userId), {
      puan: puan,
      kullaniciAdi: kullaniciAdi,
      userId: userId,
      emoji: emoji, // Düzeltilmiş değişkeni kullan
    });
  }

  await batch.commit();
  logger.info("MEVCUT HAFTALIK liderlik tablosu başarıyla güncellendi.");
  return null;
}); // Haftalık fonksiyon bitti


/**
 * MEVCUT AYLIK Liderlik Tablosunu Hesaplar.
 * Her 10 dakikada bir çalışır.
 */
exports.calculateCurrentMonthlyLeaderboard = onSchedule({
  schedule: "*/10 * * * *",
  timeZone: "Europe/Istanbul",
}, async (event) => {
  logger.info("MEVCUT AYLIK liderlik hesaplaması başlıyor (10dk)...");

  const now = new Date();
  const startOfThisMonth = new Date(now.getFullYear(), now.getMonth(), 1);
  startOfThisMonth.setHours(0, 0, 0, 0);

  logger.info(`Hesaplanan Ay Aralığı: ${startOfThisMonth.toISOString()} - ${now.toISOString()}`);

  const solvedQuizzesRef = db
      .collectionGroup("solvedQuizzes")
      .where("tarih", ">=", startOfThisMonth);
  const snapshot = await solvedQuizzesRef.get();

  const monthlyScores = new Map();
  snapshot.forEach((doc) => {
    const data = doc.data();
    const puan = data.puan || 0;
    const userId = doc.ref.parent.parent.id;
    const currentScore = monthlyScores.get(userId) || 0;
    monthlyScores.set(userId, currentScore + puan);
  });
  logger.info(`Toplam ${monthlyScores.size} kullanıcının aylık puanı hesaplandı.`);

  const batch = db.batch();
  const leaderboardRef = db.collection("mevcutAylikLiderlik");

  const oldEntries = await leaderboardRef.get();
  oldEntries.forEach((doc) => batch.delete(doc.ref));

  for (const [userId, puan] of monthlyScores.entries()) {
    const userDoc = await db.collection("users").doc(userId).get();
    let kullaniciAdi = "İsimsiz Kullanıcı";
    let emoji = "🙂"; // Varsayılan emoji

    if (userDoc.exists) {
      const userData = userDoc.data();
      // --- DÜZELTME: 'kullaniciAdi' alma mantığı ---
      if (userData && userData.kullaniciAdi) {
        kullaniciAdi = userData.kullaniciAdi;
      } else if (userData && userData.email) {
        kullaniciAdi = userData.email;
      }
      // --- DÜZELTME: 'emoji' alma mantığı (?. kaldırıldı) ---
      if (userData && userData.emoji) {
        emoji = userData.emoji;
      }
    }

    batch.set(leaderboardRef.doc(userId), {
      puan: puan,
      kullaniciAdi: kullaniciAdi,
      userId: userId,
      emoji: emoji, // Düzeltilmiş değişkeni kullan
    });
  }

  await batch.commit();
  logger.info("MEVCUT AYLIK liderlik tablosu başarıyla güncellendi.");
  return null;
}); // Aylık fonksiyon bitti
