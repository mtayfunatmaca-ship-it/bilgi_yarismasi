/* eslint-disable no-unused-vars */
/* eslint-disable object-curly-spacing */
/* eslint-disable max-len */

const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onDocumentWritten, onDocumentCreated} = require("firebase-functions/v2/firestore"); // YENİ IMPORT
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

// === YARDIMCI FONKSİYON: Kullanıcı Verisini Alır (PRO Dahil) ===
async function getUserDetails(userId) {
  const userDoc = await db.collection("users").doc(userId).get();
  if (userDoc.exists) {
    const userData = userDoc.data();
    return {
      kullaniciAdi: userData.ad || userData.kullaniciAdi || userData.email || "İsimsiz",
      emoji: userData.emoji || "🙂",
      isPro: userData.isPro || false,
      userId: userId,
    };
  }
  return { kullaniciAdi: "Kullanıcı", emoji: "🙂", isPro: false, userId: userId };
}

// === YARDIMCI FONKSİYON: Haftalık/Aylık Skorları TEKRAR HESAPLAR ===
async function recalculateLeaderboardScores(userId) {
  // Bu fonksiyon, kullanıcının o haftaki/aydaki toplam skorunu yeniden hesaplar

  const now = new Date();
  const startOfThisWeek = getStartOfWeek(now);
  const startOfThisMonth = new Date(now.getFullYear(), now.getMonth(), 1);
  startOfThisMonth.setHours(0, 0, 0, 0);

  const userSolvedQuizzesRef = db.collection("users").doc(userId).collection("solvedQuizzes");

  // 1. HAFTALIK SKOR HESAPLA
  let totalWeeklyScore = 0;
  const weeklySnapshot = await userSolvedQuizzesRef
      .where("tarih", ">=", startOfThisWeek)
      .get();
  weeklySnapshot.forEach((doc) => {
    totalWeeklyScore += doc.data().puan || 0;
  });

  // 2. AYLIK SKOR HESAPLA
  let totalMonthlyScore = 0;
  const monthlySnapshot = await userSolvedQuizzesRef
      .where("tarih", ">=", startOfThisMonth)
      .get();
  monthlySnapshot.forEach((doc) => {
    totalMonthlyScore += doc.data().puan || 0;
  });

  return { totalWeeklyScore, totalMonthlyScore };
}


/**
 * KRİTİK: ANLIK SKOR GÜNCELLEMESİ (onDocumentWritten)
 * Bir kullanıcı bir testi çözdüğünde (yani 'solvedQuizzes' alt koleksiyonuna yeni belge yazıldığında) çalışır.
 */
exports.updateLeaderboardsInstantly = onDocumentWritten({
  document: "users/{userId}/solvedQuizzes/{quizId}", // Hangi belgenin tetiklediği
  region: "europe-west3", // Fonksiyonunuzun bölgesi
}, async (event) => {
  if (!event.data) return null; // Belge yoksa çık

  const userId = event.params.userId;
  logger.info(`Anlık Leaderboard Güncellemesi Tetiklendi: Kullanıcı ${userId}`);

  // Tüm skorları yeniden hesapla (Çözülen test sayısındaki değişiklik nedeniyle)
  const { totalWeeklyScore, totalMonthlyScore } = await recalculateLeaderboardScores(userId);
  const userDetails = await getUserDetails(userId);

  const batch = db.batch();

  // 1. HAFTALIK LİDERLİK GÜNCELLEMESİ
  const weeklyRef = db.collection("mevcutHaftalikLiderlik").doc(userId);
  batch.set(weeklyRef, {
    puan: totalWeeklyScore,
    kullaniciAdi: userDetails.kullaniciAdi,
    userId: userId,
    emoji: userDetails.emoji,
    isPro: userDetails.isPro,
    sonGuncelleme: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  // 2. AYLIK LİDERLİK GÜNCELLEMESİ
  const monthlyRef = db.collection("mevcutAylikLiderlik").doc(userId);
  batch.set(monthlyRef, {
    puan: totalMonthlyScore,
    kullaniciAdi: userDetails.kullaniciAdi,
    userId: userId,
    emoji: userDetails.emoji,
    isPro: userDetails.isPro,
    sonGuncelleme: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  await batch.commit();
  logger.info(`Anlık skorlar kaydedildi. Haftalık: ${totalWeeklyScore}, Aylık: ${totalMonthlyScore}`);
  return null;
});
// --- KRİTİK FONKSİYON BİTTİ ---


/**
 * HAFTALIK LİDERİ İLAN EDER. (Pazar 23:59) (SADECE İLAN)
 * Artık puan hesaplamaz, sadece lideri kopyalar.
 */
exports.announceWeeklyWinner = onSchedule({
  schedule: "00 00 * * 0",
  timeZone: "Europe/Istanbul",
}, async (event) => {
  logger.info("HAFTALIK LİDER İLAN EDİLİYOR...");

  const leaderboardRef = db.collection("mevcutHaftalikLiderlik");
  const leadersSnapshot = await leaderboardRef.orderBy("puan", "desc").limit(1).get();

  if (!leadersSnapshot.empty) {
    const winnerData = leadersSnapshot.docs[0].data();
    const winnerRef = db.collection("leaders").doc("weeklyWinner");
    const winnerDetails = await getUserDetails(winnerData.userId);

    await winnerRef.set({
      kullaniciAdi: winnerDetails.kullaniciAdi,
      emoji: winnerDetails.emoji,
      puan: winnerData.puan,
      userId: winnerData.userId,
      isPro: winnerDetails.isPro,
      announcementTime: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(`🎉 Haftanın Lideri İlan Edildi: ${winnerDetails.kullaniciAdi}`);
  }
  return null;
});

/**
 * AYLIK LİDERİ İLAN EDER. (Ayın 1'i 23:59) (SADECE İLAN)
 * Artık puan hesaplamaz, sadece lideri kopyalar.
 */
exports.announceMonthlyWinner = onSchedule({
  schedule: "00 00 1 * *",
  timeZone: "Europe/Istanbul",
}, async (event) => {
  logger.info("AYLIK LİDER İLAN EDİLİYOR...");

  const leaderboardRef = db.collection("mevcutAylikLiderlik");
  const leadersSnapshot = await leaderboardRef.orderBy("puan", "desc").limit(1).get();

  if (!leadersSnapshot.empty) {
    const winnerData = leadersSnapshot.docs[0].data();
    const winnerRef = db.collection("leaders").doc("monthlyWinner");
    const winnerDetails = await getUserDetails(winnerData.userId);

    await winnerRef.set({
      kullaniciAdi: winnerDetails.kullaniciAdi,
      emoji: winnerDetails.emoji,
      puan: winnerData.puan,
      userId: winnerData.userId,
      isPro: winnerDetails.isPro,
      announcementTime: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(`🎉 Ayın Lideri İlan Edildi: ${winnerDetails.kullaniciAdi}`);
  }
  return null;
});
