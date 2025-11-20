/* eslint-disable no-unused-vars */
/* eslint-disable object-curly-spacing */
/* eslint-disable max-len */

const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onDocumentWritten} = require("firebase-functions/v2/firestore");
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
      // ✅ DÜZELTME YAPILDI: Öncelik KULLANICI ADI'na verildi.
      kullaniciAdi: userData.kullaniciAdi || userData.ad || userData.email || "İsimsiz",
      emoji: userData.emoji || "🙂",
      isPro: userData.isPro || false,
      userId: userId,
    };
  }
  return { kullaniciAdi: "Kullanıcı", emoji: "🙂", isPro: false, userId: userId };
}

// === YARDIMCI FONKSİYON: Haftalık/Aylık Skorları TEKRAR HESAPLAR ===
async function recalculateLeaderboardScores(userId) {
  const now = new Date();
  const startOfThisWeek = getStartOfWeek(now);
  const startOfThisMonth = new Date(now.getFullYear(), now.getMonth(), 1);
  startOfThisMonth.setHours(0, 0, 0, 0);

  const userSolvedQuizzesRef = db.collection("users").doc(userId).collection("solvedQuizzes");

  // 1. HAFTALIK SKOR HESAPLA (Pazartesi'den beri)
  let totalWeeklyScore = 0;
  const weeklySnapshot = await userSolvedQuizzesRef
      .where("tarih", ">=", startOfThisWeek)
      .get();
  weeklySnapshot.forEach((doc) => {
    totalWeeklyScore += doc.data().puan || 0;
  });

  // 2. AYLIK SKOR HESAPLA (Ayın 1'inden beri)
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
 * KRİTİK 1: ANLIK SKOR GÜNCELLEMESİ (Test bitince tetiklenir)
 * Alt koleksiyonu dinler ve puanları yeniden hesaplar.
 */
exports.updateLeaderboardsInstantly = onDocumentWritten({
  document: "users/{userId}/solvedQuizzes/{quizId}", // DOĞRU TETİKLEYİCİ YOLU
  region: "europe-west3",
}, async (event) => {
  if (!event.data) return null;

  const userId = event.params.userId;
  logger.info(`ANLIK SKOR GÜNCELLEME TETİKLENDİ: Kullanıcı ${userId} yeni test çözdü.`);

  const { totalWeeklyScore, totalMonthlyScore } = await recalculateLeaderboardScores(userId);
  const userDetails = await getUserDetails(userId);

  const batch = db.batch();

  // 1. HAFTALIK LİDERLİK GÜNCELLEMESİ (Canlı)
  const weeklyRef = db.collection("mevcutHaftalikLiderlik").doc(userId);
  batch.set(weeklyRef, {
    puan: totalWeeklyScore,
    kullaniciAdi: userDetails.kullaniciAdi, // Düzeltilmiş getUserDetails çağrısı
    userId: userId,
    emoji: userDetails.emoji,
    isPro: userDetails.isPro,
    sonGuncelleme: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  // 2. AYLIK LİDERLİK GÜNCELLEMESİ (Canlı)
  const monthlyRef = db.collection("mevcutAylikLiderlik").doc(userId);
  batch.set(monthlyRef, {
    puan: totalMonthlyScore,
    kullaniciAdi: userDetails.kullaniciAdi, // Düzeltilmiş getUserDetails çağrısı
    userId: userId,
    emoji: userDetails.emoji,
    isPro: userDetails.isPro,
    sonGuncelleme: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  await batch.commit();
  logger.info(`✅ Anlık skorlar güncellendi. Haftalık: ${totalWeeklyScore}, Aylık: ${totalMonthlyScore}`);
  return null;
});


/**
 * KRİTİK 2: PROFİL DETAY GÜNCELLEMESİ (Emoji/Ad/PRO değişince tetiklenir)
 * Ana kullanıcı belgesini dinler ve haftalık/aylık tablolara sadece EMOGİ, AD, PRO bilgisini kopyalar.
 */
exports.updateLeaderboardUserDetails = onDocumentWritten({
  document: "users/{userId}", // <<< DOĞRU TETİKLEYİCİ: Ana belgeyi dinler
  region: "europe-west3",
}, async (event) => {
  // Belge silme işlemi (delete) değilse ve veri varsa devam et
  if (!event.data) return null;

  const userId = event.params.userId;
  logger.info(`PROFİL DETAY GÜNCELLEMESİ TETİKLENDİ: Kullanıcı ${userId}`);

  const userDetails = await getUserDetails(userId); // Düzeltilmiş getUserDetails çağrısı

  const batch = db.batch();

  // 1. Canlı Haftalık Tabloyu Güncelle (Puanı koru)
  const weeklyRef = db.collection("mevcutHaftalikLiderlik").doc(userId);
  batch.set(weeklyRef, {
    kullaniciAdi: userDetails.kullaniciAdi,
    emoji: userDetails.emoji,
    isPro: userDetails.isPro,
  }, { merge: true });

  // 2. Canlı Aylık Tabloyu Güncelle (Puanı koru)
  const monthlyRef = db.collection("mevcutAylikLiderlik").doc(userId);
  batch.set(monthlyRef, {
    kullaniciAdi: userDetails.kullaniciAdi,
    emoji: userDetails.emoji,
    isPro: userDetails.isPro,
  }, { merge: true });

  // --- KRİTİK DÜZELTME: İlan Edilmiş Liderin Bilgisini KONTROLLÜ Güncelleme ---
  // Sadece emojiyi ve adı güncelle, puanı KESİNLİKLE elleme.
  const winnerDetailsUpdate = {
    kullaniciAdi: userDetails.kullaniciAdi,
    emoji: userDetails.emoji,
    isPro: userDetails.isPro,
  };

  const weeklyWinnerRef = db.collection("leaders").doc("weeklyWinner");
  const monthlyWinnerRef = db.collection("leaders").doc("monthlyWinner");

  // NOT: Liderin ID'si değişmediği sürece bu güvenlidir.
  // UPDATE yerine SET(merge: true) kullandığımız için puan korunur.
  batch.set(weeklyWinnerRef, winnerDetailsUpdate, { merge: true });
  batch.set(monthlyWinnerRef, winnerDetailsUpdate, { merge: true });

  await batch.commit();
  logger.info(`✅ Kullanıcı detayları (Emoji/PRO/Ad) anlık olarak yansıtıldı.`);
  return null;
});
// --- PROFİL GÜNCELLEMESİ BİTTİ ---


/**
 * HAFTALIK LİDERİ İLAN EDER. (Pazartesi 00:00)
 */
exports.announceWeeklyWinner = onSchedule({
  schedule: "00 00 * * 0", // Pazartesi 00:00
  timeZone: "Europe/Istanbul",
}, async (event) => {
  logger.info("HAFTALIK LİDER İLAN EDİLİYOR...");

  const leaderboardRef = db.collection("mevcutHaftalikLiderlik");
  const leadersSnapshot = await leaderboardRef.orderBy("puan", "desc").limit(1).get();

  if (!leadersSnapshot.empty) {
    const winnerData = leadersSnapshot.docs[0].data();
    const winnerRef = db.collection("leaders").doc("weeklyWinner");

    const winnerDetails = await getUserDetails(winnerData.userId); // Düzeltilmiş getUserDetails çağrısı

    await winnerRef.set({
      kullaniciAdi: winnerDetails.kullaniciAdi,
      emoji: winnerDetails.emoji,
      puan: winnerData.puan, // Bu, sabitlenen puandır
      userId: winnerData.userId,
      isPro: winnerDetails.isPro,
      announcementTime: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(`🎉 Haftanın Lideri İlan Edildi: ${winnerDetails.kullaniciAdi}`);
  }
  return null;
});

/**
 * AYLIK LİDERİ İLAN EDER. (Ayın 2'si 00:00)
 */
exports.announceMonthlyWinner = onSchedule({
  schedule: "00 00 1 * *", // Ayın 2'si 00:00
  timeZone: "Europe/Istanbul",
}, async (event) => {
  logger.info("AYLIK LİDER İLAN EDİLİYOR...");

  const leaderboardRef = db.collection("mevcutAylikLiderlik");
  const leadersSnapshot = await leaderboardRef.orderBy("puan", "desc").limit(1).get();

  if (!leadersSnapshot.empty) {
    const winnerData = leadersSnapshot.docs[0].data();
    const winnerRef = db.collection("leaders").doc("monthlyWinner");

    const winnerDetails = await getUserDetails(winnerData.userId); // Düzeltilmiş getUserDetails çağrısı

    await winnerRef.set({
      kullaniciAdi: winnerDetails.kullaniciAdi,
      emoji: winnerDetails.emoji,
      puan: winnerData.puan, // Bu, sabitlenen puandır
      userId: winnerData.userId,
      isPro: winnerDetails.isPro,
      announcementTime: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(`🎉 Ayın Lideri İlan Edildi: ${winnerDetails.kullaniciAdi}`);
  }
  return null;
});
