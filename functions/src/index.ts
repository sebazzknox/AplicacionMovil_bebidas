// functions/src/index.ts
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";

initializeApp();
const db = getFirestore();

/**
 * Envía push a quienes activaron "notifyofertas"
 * cuando se crea una oferta en /ofertas.
 */
export const notifyOnNewOffer = onDocumentCreated(
  "ofertas/{ofertaId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data =
      (snap.data() || {}) as Record<string, unknown>;
    const titulo =
      (data["titulo"] as string | undefined) ?? "Nueva oferta";
    const comercioId =
      (data["comercioId"] as string | undefined) ?? "";

    // Usuarios que quieren notificaciones
    const users = await db
      .collection("users")
      .where("notifyofertas", "==", true)
      .get();

    // Tokens únicos
    const tokens = new Set<string>();
    users.forEach((u) => {
      const t = (u.get("fcmToken") as string | undefined)?.trim();
      if (t) tokens.add(t);
    });
    if (tokens.size === 0) return;

    // Envío
    await getMessaging().sendMulticast({
      tokens: Array.from(tokens),
      notification: {
        title: "¡Nueva oferta!",
        body: titulo,
      },
      data: {
        type: "oferta",
        ofertaId: snap.id,
        comercioId,
      },
      android: {
        priority: "high", // 👈 va aquí
        notification: {channelId: "offers"},
      },
      apns: {payload: {aps: {sound: "default"}}},
    });
  }
);
