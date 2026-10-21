import * as admin from "firebase-admin";
import {HttpsError, onCall} from "firebase-functions/v2/https";

interface RequestedOrderItem {
  productId: string;
  quantity: number;
}

interface ShippingAddressInput {
  id: string;
  recipientName: string;
  phoneNumber: string;
  province: string;
  district: string;
  ward: string;
  streetAddress: string;
  isDefault?: boolean;
}

interface CreateOrderInput {
  idempotencyKey: string;
  items: RequestedOrderItem[];
  shippingAddress: ShippingAddressInput;
  shippingMethod: "standard" | "express";
  paymentMethod: "COD" | "ONLINE";
  couponCode?: string | null;
  customerNote?: string | null;
}

interface CancelOrderInput {
  orderId: string;
  reason: string;
}

const REGION = "asia-southeast1";
const FREE_SHIPPING_THRESHOLD = 2000000;
const STANDARD_SHIPPING_FEE = 30000;
const EXPRESS_SHIPPING_FEE = 60000;

export const createOrder = onCall(
  {region: REGION},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Vui lòng đăng nhập để thực hiện đặt hàng."
      );
    }

    const userId = request.auth.uid;
    const userEmail = (request.auth.token.email as string) ?? "";
    const data = request.data as CreateOrderInput;

    const idempotencyKey = (data.idempotencyKey ?? "").trim();
    if (idempotencyKey.length < 8) {
      throw new HttpsError(
        "invalid-argument",
        "Thiếu khóa chống trùng lặp đơn hàng (idempotencyKey)."
      );
    }

    if (!Array.isArray(data.items) || data.items.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "Danh sách sản phẩm đặt mua không được để trống."
      );
    }

    const addr = data.shippingAddress;
    if (
      !addr ||
      !addr.recipientName?.trim() ||
      !addr.phoneNumber?.trim() ||
      !addr.province?.trim() ||
      !addr.district?.trim() ||
      !addr.ward?.trim() ||
      !addr.streetAddress?.trim()
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Thông tin địa chỉ giao hàng chưa đầy đủ."
      );
    }

    const db = admin.firestore();
    const idempotencyRef = db
      .collection("order_idempotency")
      .doc(idempotencyKey);

    return await db.runTransaction(async (transaction) => {
      // 1. Kiểm tra chống tạo đơn trùng
      const idemSnap = await transaction.get(idempotencyRef);
      if (idemSnap.exists) {
        const existingOrderId = idemSnap.data()?.orderId as string;
        return {
          orderId: existingOrderId,
          deduplicated: true,
        };
      }

      // 2. Gom nhóm số lượng theo productId và đọc toàn bộ sản phẩm trong Transaction
      const mergedQtyMap = new Map<string, number>();
      for (const rawItem of data.items) {
        const pid = (rawItem.productId ?? "").trim();
        const qty = Math.floor(Number(rawItem.quantity ?? 0));
        if (!pid || qty <= 0) {
          throw new HttpsError(
            "invalid-argument",
            "Số lượng hoặc mã sản phẩm không hợp lệ."
          );
        }
        mergedQtyMap.set(pid, (mergedQtyMap.get(pid) ?? 0) + qty);
      }

      const productEntries = Array.from(mergedQtyMap.entries());
      const productRefs = productEntries.map(([pid]) =>
        db.collection("products").doc(pid)
      );
      const productSnaps = await Promise.all(
        productRefs.map((ref) => transaction.get(ref))
      );

      // 3. Kiểm tra mã giảm giá (nếu có)
      const normalizedCoupon = (data.couponCode ?? "").trim().toUpperCase();
      let couponSnap: admin.firestore.DocumentSnapshot | null = null;
      if (normalizedCoupon.length > 0) {
        const couponRef = db.collection("coupons").doc(normalizedCoupon);
        couponSnap = await transaction.get(couponRef);
        if (!couponSnap.exists) {
          throw new HttpsError(
            "not-found",
            `Mã giảm giá "${normalizedCoupon}" không tồn tại.`
          );
        }
      }

      // 4. Xác minh tồn kho, giá bán số nguyên VND và tạo Snapshot từng mặt hàng
      let subtotal = 0;
      const snapshotItems: Array<Record<string, unknown>> = [];
      const stockUpdates: Array<{
        ref: admin.firestore.DocumentReference;
        productId: string;
        sku: string;
        previousStock: number;
        newStock: number;
        newAvailable: number;
        newSoldCount: number;
        quantity: number;
      }> = [];

      for (let i = 0; i < productEntries.length; i++) {
        const [productId, requestedQty] = productEntries[i];
        const pSnap = productSnaps[i];
        if (!pSnap.exists) {
          throw new HttpsError(
            "not-found",
            `Sản phẩm (${productId}) không tồn tại.`
          );
        }

        const pData = pSnap.data() ?? {};
        const isActive = pData.isActive === true;
        const isDeleted = pData.isDeleted === true;
        const productName = String(pData.name ?? "Linh kiện điện tử");

        if (!isActive || isDeleted) {
          throw new HttpsError(
            "failed-precondition",
            `Sản phẩm "${productName}" hiện đã ngừng kinh doanh.`
          );
        }

        const stockQuantity = Math.floor(Number(pData.stockQuantity ?? 0));
        const reservedQuantity = Math.floor(
          Number(pData.reservedQuantity ?? 0)
        );
        const availableStock = Math.max(0, stockQuantity - reservedQuantity);

        if (availableStock < requestedQty) {
          throw new HttpsError(
            "failed-precondition",
            `Sản phẩm "${productName}" chỉ còn ${availableStock} sản phẩm trong kho.`
          );
        }

        const unitPrice = Math.floor(Number(pData.price ?? 0));
        const rawSale =
          pData.salePrice !== null && pData.salePrice !== undefined
            ? Math.floor(Number(pData.salePrice))
            : null;
        const finalUnitPrice =
          rawSale !== null && rawSale > 0 && rawSale < unitPrice
            ? rawSale
            : unitPrice;

        if (finalUnitPrice <= 0) {
          throw new HttpsError(
            "failed-precondition",
            `Giá của sản phẩm "${productName}" không hợp lệ.`
          );
        }

        const lineTotal = finalUnitPrice * requestedQty;
        subtotal += lineTotal;

        const sku = String(pData.sku ?? productId.toUpperCase());
        snapshotItems.push({
          productId,
          sku,
          productName,
          brandName: String(pData.brandName ?? ""),
          thumbnailUrl: String(pData.thumbnailUrl ?? ""),
          unitPrice,
          finalUnitPrice,
          quantity: requestedQty,
          lineTotal,
          warrantyMonths: Math.floor(Number(pData.warrantyMonths ?? 12)),
          isReviewed: false,
        });

        const newStock = stockQuantity - requestedQty;
        const newAvailable = Math.max(0, newStock - reservedQuantity);
        const currentSold = Math.floor(Number(pData.soldCount ?? 0));

        stockUpdates.push({
          ref: pSnap.ref,
          productId,
          sku,
          previousStock: stockQuantity,
          newStock,
          newAvailable,
          newSoldCount: currentSold + requestedQty,
          quantity: requestedQty,
        });
      }

      // 5. Tính giảm giá từ Coupon phía máy chủ
      let discountAmount = 0;
      let appliedCouponCode: string | null = null;
      if (couponSnap && couponSnap.exists) {
        const cData = couponSnap.data() ?? {};
        const nowMs = Date.now();
        const startMs =
          (cData.startDate as admin.firestore.Timestamp)?.toMillis() ?? 0;
        const endMs =
          (cData.endDate as admin.firestore.Timestamp)?.toMillis() ?? 0;
        const usedCount = Math.floor(Number(cData.usedCount ?? 0));
        const usageLimit = Math.floor(Number(cData.usageLimit ?? 0));
        const minOrderAmount = Math.floor(Number(cData.minOrderAmount ?? 0));

        if (
          cData.isActive !== true ||
          nowMs < startMs ||
          nowMs > endMs ||
          usedCount >= usageLimit
        ) {
          throw new HttpsError(
            "failed-precondition",
            `Mã giảm giá "${normalizedCoupon}" đã hết hạn hoặc hết lượt sử dụng.`
          );
        }

        if (subtotal < minOrderAmount) {
          throw new HttpsError(
            "failed-precondition",
            `Đơn hàng chưa đạt mức tối thiểu ${minOrderAmount} ₫ để dùng mã "${normalizedCoupon}".`
          );
        }

        const discountType = String(cData.discountType ?? "fixed");
        const discountValue = Math.floor(Number(cData.discountValue ?? 0));
        if (discountType === "percentage") {
          const pct = Math.min(100, Math.max(0, discountValue));
          discountAmount = Math.floor((subtotal * pct) / 100);
          if (
            cData.maxDiscountAmount !== null &&
            cData.maxDiscountAmount !== undefined
          ) {
            const maxCap = Math.floor(Number(cData.maxDiscountAmount));
            if (maxCap > 0 && discountAmount > maxCap) {
              discountAmount = maxCap;
            }
          }
        } else {
          discountAmount = discountValue;
        }
        discountAmount = Math.min(subtotal, Math.max(0, discountAmount));
        appliedCouponCode = normalizedCoupon;

        transaction.update(couponSnap.ref, {
          usedCount: usedCount + 1,
        });
      }

      // 6. Tính phí vận chuyển & Tổng tiền thanh toán cuối cùng (VND - int)
      const afterDiscount = subtotal - discountAmount;
      let shippingFee = 0;
      if (data.shippingMethod === "express") {
        shippingFee =
          afterDiscount >= FREE_SHIPPING_THRESHOLD
            ? 30000
            : EXPRESS_SHIPPING_FEE;
      } else {
        shippingFee =
          afterDiscount >= FREE_SHIPPING_THRESHOLD ? 0 : STANDARD_SHIPPING_FEE;
      }

      const totalAmount = Math.max(0, afterDiscount + shippingFee);
      const nowTimestamp = admin.firestore.Timestamp.now();
      const orderRef = db.collection("orders").doc();
      const shortSuffix = orderRef.id.substring(0, 5).toUpperCase();
      const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, "");
      const orderCode = `ORD-${dateStr}-${shortSuffix}`;

      // 7. Trừ kho sản phẩm và ghi lịch sử biến động kho
      for (const stockUpd of stockUpdates) {
        transaction.update(stockUpd.ref, {
          stockQuantity: stockUpd.newStock,
          availableStock: stockUpd.newAvailable,
          inStock: stockUpd.newAvailable > 0,
          soldCount: stockUpd.newSoldCount,
          updatedAt: nowTimestamp,
        });

        const txRef = db.collection("inventory_transactions").doc();
        transaction.set(txRef, {
          id: txRef.id,
          productId: stockUpd.productId,
          sku: stockUpd.sku,
          orderId: orderRef.id,
          type: "commit_deduct",
          quantityChange: -stockUpd.quantity,
          previousStock: stockUpd.previousStock,
          newStock: stockUpd.newStock,
          reason: `Trừ kho khi tạo đơn hàng ${orderCode}`,
          performedBy: userId,
          createdAt: nowTimestamp,
        });
      }

      // 8. Lưu khóa chống trùng lặp và tạo document đơn hàng
      transaction.set(idempotencyRef, {
        idempotencyKey,
        orderId: orderRef.id,
        userId,
        createdAt: nowTimestamp,
      });

      const fullAddressText =
        `${addr.streetAddress.trim()}, ${addr.ward.trim()}, ` +
        `${addr.district.trim()}, ${addr.province.trim()}`;

      transaction.set(orderRef, {
        id: orderRef.id,
        orderCode,
        idempotencyKey,
        userId,
        userEmail,
        items: snapshotItems,
        shippingAddress: {
          id: addr.id ?? "addr",
          recipientName: addr.recipientName.trim(),
          phoneNumber: addr.phoneNumber.trim(),
          province: addr.province.trim(),
          district: addr.district.trim(),
          ward: addr.ward.trim(),
          streetAddress: addr.streetAddress.trim(),
          fullAddressText,
        },
        shippingMethod: data.shippingMethod,
        shippingFee,
        couponCode: appliedCouponCode,
        discountAmount,
        subtotal,
        totalAmount,
        paymentMethod: data.paymentMethod === "ONLINE" ? "ONLINE" : "COD",
        paymentStatus: "pending",
        paymentTransactionId: null,
        status: "pending_confirmation",
        statusHistory: [
          {
            status: "pending_confirmation",
            note: "Đơn hàng đã được khởi tạo thành công và đang chờ xác nhận.",
            changedBy: userId,
            changedAt: nowTimestamp,
          },
        ],
        customerNote: data.customerNote?.trim() || null,
        cancelReason: null,
        createdAt: nowTimestamp,
        updatedAt: nowTimestamp,
      });

      // 9. Tạo thông báo xác nhận đơn hàng cho người mua
      const notifRef = db.collection("notifications").doc();
      transaction.set(notifRef, {
        id: notifRef.id,
        userId,
        title: `Đặt hàng thành công (${orderCode})`,
        body: `Đơn hàng trị giá ${totalAmount} ₫ của bạn đã được tiếp nhận.`,
        type: "order_status",
        referenceId: orderRef.id,
        isRead: false,
        createdAt: nowTimestamp,
      });

      return {
        orderId: orderRef.id,
        orderCode,
        totalAmount,
        deduplicated: false,
      };
    });
  }
);

export const cancelOrder = onCall(
  {region: REGION},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Vui lòng đăng nhập.");
    }

    const userId = request.auth.uid;
    const role = (request.auth.token.role as string) ?? "customer";
    const isStaffOrAdmin = role === "admin" || role === "staff";
    const data = request.data as CancelOrderInput;

    const orderId = (data.orderId ?? "").trim();
    const reason =
      (data.reason ?? "").trim() || "Khách hàng yêu cầu hủy đơn hàng";

    if (!orderId) {
      throw new HttpsError("invalid-argument", "Thiếu mã đơn hàng cần hủy.");
    }

    const db = admin.firestore();
    const orderRef = db.collection("orders").doc(orderId);

    return await db.runTransaction(async (transaction) => {
      const orderSnap = await transaction.get(orderRef);
      if (!orderSnap.exists) {
        throw new HttpsError("not-found", "Không tìm thấy đơn hàng.");
      }

      const orderData = orderSnap.data() ?? {};
      if (orderData.userId !== userId && !isStaffOrAdmin) {
        throw new HttpsError(
          "permission-denied",
          "Bạn không có quyền hủy đơn hàng này."
        );
      }

      const currentStatus = String(orderData.status ?? "");
      if (currentStatus === "cancelled") {
        return {orderId, alreadyCancelled: true};
      }

      const cancellableByCustomer = [
        "pending_confirmation",
        "confirmed",
      ].includes(currentStatus);

      if (!cancellableByCustomer && !isStaffOrAdmin) {
        throw new HttpsError(
          "failed-precondition",
          "Đơn hàng đã chuyển sang khâu chuẩn bị/vận chuyển nên không thể tự hủy."
        );
      }

      const items = (orderData.items as Array<Record<string, unknown>>) ?? [];
      const productRefs = items.map((item) =>
        db.collection("products").doc(String(item.productId))
      );
      const productSnaps = await Promise.all(
        productRefs.map((ref) => transaction.get(ref))
      );

      const nowTimestamp = admin.firestore.Timestamp.now();

      // Hoàn lại tồn kho cho từng mặt hàng trong đơn
      for (let i = 0; i < items.length; i++) {
        const item = items[i];
        const pSnap = productSnaps[i];
        if (!pSnap.exists) continue;

        const pData = pSnap.data() ?? {};
        const qty = Math.floor(Number(item.quantity ?? 0));
        const prevStock = Math.floor(Number(pData.stockQuantity ?? 0));
        const reserved = Math.floor(Number(pData.reservedQuantity ?? 0));
        const prevSold = Math.floor(Number(pData.soldCount ?? 0));

        const newStock = prevStock + qty;
        const newAvailable = Math.max(0, newStock - reserved);
        const newSold = Math.max(0, prevSold - qty);

        transaction.update(pSnap.ref, {
          stockQuantity: newStock,
          availableStock: newAvailable,
          inStock: newAvailable > 0,
          soldCount: newSold,
          updatedAt: nowTimestamp,
        });

        const txRef = db.collection("inventory_transactions").doc();
        transaction.set(txRef, {
          id: txRef.id,
          productId: String(item.productId),
          sku: String(item.sku ?? ""),
          orderId,
          type: "restock",
          quantityChange: qty,
          previousStock: prevStock,
          newStock,
          reason: `Hoàn kho do hủy đơn hàng ${orderData.orderCode ?? orderId}`,
          performedBy: userId,
          createdAt: nowTimestamp,
        });
      }

      const existingHistory = Array.isArray(orderData.statusHistory)
        ? orderData.statusHistory
        : [];

      transaction.update(orderRef, {
        status: "cancelled",
        cancelReason: reason,
        updatedAt: nowTimestamp,
        statusHistory: [
          ...existingHistory,
          {
            status: "cancelled",
            note: `Đơn hàng đã bị hủy. Lý do: ${reason}`,
            changedBy: userId,
            changedAt: nowTimestamp,
          },
        ],
      });

      return {orderId, alreadyCancelled: false};
    });
  }
);