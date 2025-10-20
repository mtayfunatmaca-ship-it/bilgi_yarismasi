/* eslint-disable no-unused-vars */
/* eslint-disable object-curly-spacing */

const {onSchedule} = require("firebase-functions/v2/scheduler");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

/**
 * Haftalık Liderlik Tablosunu Hesaplayan Cloud Function (V2 Syntax).
 * Türkiye Saati ile Her Pazar 23:59'da çalışır.
 */
exports.calculateWeeklyLeaderboardV2 = onSchedule({
  schedule: "every sunday 23:59",
  timeZone: "Europe/Istanbul",
}, async (event) => {
  logger.info("Haftalık liderlik tablosu hesaplaması başlıyor (TR Saati)...");

  const oneWeekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

  const solvedQuizzesRef = db
      .collectionGroup("solvedQuizzes")
      .where("tarih", ">=", oneWeekAgo);

  const snapshot = await solvedQuizzesRef.get();

  if (snapshot.empty) {
    logger.info("Son 7 günde çözülmüş test bulunamadı.");
    const leaderboardRef = db.collection("haftalikLiderlik");
    const oldEntries = await leaderboardRef.get();
    if (!oldEntries.empty) {
      const batch = db.batch();
      oldEntries.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
      logger.info("Eski haftalık liderlik tablosu temizlendi.");
    }
    return null;
  }

  const weeklyScores = new Map();

  snapshot.forEach((doc) => {
    const data = doc.data();
    const puan = data.puan || 0;
    const userId = doc.ref.parent.parent.id;
    const currentScore = weeklyScores.get(userId) || 0;
    weeklyScores.set(userId, currentScore + puan);
  });

  logger.info(
      `Toplam ${weeklyScores.size} kullanıcının puanı hesaplandı.`,
  );

  const batch = db.batch();
  const leaderboardRef = db.collection("haftalikLiderlik");

  const oldEntries = await leaderboardRef.get();
  oldEntries.forEach((doc) => {
    batch.delete(doc.ref);
  });

  for (const [userId, puan] of weeklyScores.entries()) {
    const userDoc = await db.collection("users").doc(userId).get();
    let kullaniciAdi = "İsimsiz Kullanıcı";
    if (userDoc.exists) {
      // --- DÜZELTME: Kullanıcı adı alma mantığı değiştirildi ---
      const userData = userDoc.data();
      // Önce userData'nın varlığını kontrol et
      if (userData) {
        if (userData.kullaniciAdi) { // Sonra alanı kontrol et
          kullaniciAdi = userData.kullaniciAdi;
        } else if (userData.email) {
          kullaniciAdi = userData.email;
        }
      }
      // --- DÜZELTME BİTTİ ---
    }

    const newEntryRef = leaderboardRef.doc(userId);
    batch.set(newEntryRef, {
      puan: puan,
      kullaniciAdi: kullaniciAdi,
      userId: userId,
    });
  }

  await batch.commit();

  logger.info("Haftalık liderlik tablosu başarıyla güncellendi (V2).");
  return null;
}); // Haftalık fonksiyon bitti

/**
 * Aylık Liderlik Tablosunu Hesaplayan Cloud Function (V2 Syntax).
 * Türkiye Saati ile Her Ayın 1'inde 00:00'da çalışır (bir önceki ayı hesaplar).
 */
exports.calculateMonthlyLeaderboard = onSchedule({
  schedule: "0 0 1 * *",
  timeZone: "Europe/Istanbul",
}, async (event) => {
  logger.info("Aylık liderlik hesaplaması başlıyor (TR Saati)...");

  const now = new Date();
  const startOfLastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  const endOfLastMonth = new Date(now.getFullYear(), now.getMonth(), 1);

  logger.info(`Hesaplanan Ay Başlangıcı: ${startOfLastMonth.toISOString()}`);
  logger.info(`Hesaplanan Ay Bitişi: ${endOfLastMonth.toISOString()}`);


  const solvedQuizzesRef = db
      .collectionGroup("solvedQuizzes")
      .where("tarih", ">=", startOfLastMonth)
      .where("tarih", "<", endOfLastMonth);

  const snapshot = await solvedQuizzesRef.get();

  if (snapshot.empty) {
    logger.info("Geçen ay çözülmüş test bulunamadı.");
    const leaderboardRef = db.collection("aylikLiderlik");
    const batch = db.batch();
    const oldEntries = await leaderboardRef.get();
    oldEntries.forEach((doc) => {
      batch.delete(doc.ref);
    });
    await batch.commit();
    logger.info("Eski aylık liderlik tablosu temizlendi.");
    return null;
  }

  const monthlyScores = new Map();

  snapshot.forEach((doc) => {
    const data = doc.data();
    const puan = data.puan || 0;
    const userId = doc.ref.parent.parent.id;
    const currentScore = monthlyScores.get(userId) || 0;
    monthlyScores.set(userId, currentScore + puan);
  });

  logger.info(
      `Toplam ${monthlyScores.size} kullanıcının aylık puanı hesaplandı.`,
  );

  const batch = db.batch();
  const leaderboardRef = db.collection("aylikLiderlik");

  const oldEntries = await leaderboardRef.get();
  oldEntries.forEach((doc) => {
    batch.delete(doc.ref);
  });

  for (const [userId, puan] of monthlyScores.entries()) {
    const userDoc = await db.collection("users").doc(userId).get();
    let kullaniciAdi = "İsimsiz Kullanıcı";
    if (userDoc.exists) {
      // --- DÜZELTME: Kullanıcı adı alma mantığı değiştirildi ---
      const userData = userDoc.data();
      if (userData) {
        if (userData.kullaniciAdi) {
          kullaniciAdi = userData.kullaniciAdi;
        } else if (userData.email) {
          kullaniciAdi = userData.email;
        }
      }
      // --- DÜZELTME BİTTİ ---
    }

    const newEntryRef = leaderboardRef.doc(userId);
    batch.set(newEntryRef, {
      puan: puan,
      kullaniciAdi: kullaniciAdi,
      userId: userId,
    });
  }

  await batch.commit();

  logger.info("Aylık liderlik tablosu başarıyla güncellendi (V2).");
  return null;
}); // Aylık fonksiyon bitti
