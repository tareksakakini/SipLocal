import * as admin from "firebase-admin";

export type OrderDocument = FirebaseFirestore.DocumentData;

function sanitize<T extends Record<string, unknown>>(data: T): T {
  const entries = Object.entries(data).filter(([, value]) => value !== undefined);
  return Object.fromEntries(entries) as T;
}

function getOrdersCollection() {
  if (!admin.apps.length) {
    throw new Error(
      "[ordersRepository] Firebase app not initialized. Call initializeApp() before using the repository."
    );
  }
  return admin.firestore().collection("orders");
}

export async function createOrder(
  orderId: string,
  data: Record<string, unknown>
): Promise<void> {
  const timestamp = admin.firestore.FieldValue.serverTimestamp();

  const document = sanitize({
    ...data,
    transactionId: data.transactionId ?? orderId,
    createdAt: timestamp,
    updatedAt: timestamp,
  });

  await getOrdersCollection().doc(orderId).set(document);
}

export async function updateOrder(
  orderId: string,
  data: Record<string, unknown>
): Promise<void> {
  const document = sanitize({
    ...data,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await getOrdersCollection().doc(orderId).update(document);
}

export async function getOrder(orderId: string): Promise<OrderDocument | null> {
  const snapshot = await getOrdersCollection().doc(orderId).get();
  if (!snapshot.exists) {
    return null;
  }
  return snapshot.data() ?? null;
}

export async function deleteOrder(orderId: string): Promise<void> {
  await getOrdersCollection().doc(orderId).delete();
}
