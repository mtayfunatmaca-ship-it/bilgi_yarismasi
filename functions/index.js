/**
 * Aylık Liderlik Güncellemesi + Aylık Birinci İlanı
 * Türkiye Saati ile her ayın 1'inde 00:00'da çalışır.
 */
exports.updateMonthlyLeaderboard = onSchedule({
  schedule: "0 0 1 * *", // Her ayın 1'i, 00:00
  timeZone: "Europe/Istanbul",
}, async (event) => {
  logger.info("Aylık liderlik tablosu güncelleniyor...");

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

  const monthlyScores = new Map();

  snapshot.forEach((doc) => {
    const data = doc.data();
    const puan = data.puan || 0;
    const userId = doc.ref.parent.parent.id;
    const currentScore = monthlyScores.get(userId) || 0;
    monthlyScores.set(userId, currentScore + puan);
  });

  const batch = db.batch();
  const leaderboardRef = db.collection("aylikLiderlik");

  // Eski tabloyu sil
  const oldEntries = await leaderboardRef.get();
  oldEntries.forEach((doc) => batch.delete(doc.ref));

  // Yeni tabloyu ekle
  for (const [userId, puan] of monthlyScores.entries()) {
    const userDoc = await db.collection("users").doc(userId).get();
    let kullaniciAdi = "İsimsiz Kullanıcı";
    if (userDoc.exists) {
      const userData = userDoc.data();
      if (userData) kullaniciAdi = userData.kullaniciAdi || userData.email || "İsimsiz Kullanıcı";
    }
    batch.set(leaderboardRef.doc(userId), {
      puan,
      kullaniciAdi,
      userId,
    });
  }

  await batch.commit();
  logger.info("Aylık liderlik tablosu güncellendi.");

  // --- Aylık birinciyi ilan etme ---
  let topUserId = null;
  let topScore = -1;
  for (const [userId, puan] of monthlyScores.entries()) {
    if (puan > topScore) {
      topScore = puan;
      topUserId = userId;
    }
  }

  if (topUserId) {
    const topUserDoc = await db.collection("users").doc(topUserId).get();
    let topUserName = "İsimsiz Kullanıcı";
    if (topUserDoc.exists) {
      const userData = topUserDoc.data();
      if (userData) topUserName = userData.kullaniciAdi || userData.email || "İsimsiz Kullanıcı";
    }

    await db.collection("ayBirincisi").doc("current").set({
      userId: topUserId,
      kullaniciAdi: topUserName,
      puan: topScore,
      tarih: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(`Ayın birincisi: ${topUserName} (puan: ${topScore})`);
  }

  return null;
});
